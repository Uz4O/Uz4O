import json
from dataclasses import dataclass
from typing import Dict, List

import httpx

from app.builds.service import BuildRequest
from app.catalog.models import ComponentPrice, HardwareComponent
from app.core.config import Settings


class AIProviderError(Exception):
    pass


@dataclass(frozen=True)
class AIProviderResult:
    components: Dict[str, str]
    explanation: str
    actual_cost_cents: int = 0


def select_build_with_deepseek(
    request: BuildRequest,
    candidates_by_role: Dict[str, List[HardwareComponent]],
    price_by_component_id: Dict[str, ComponentPrice],
    settings: Settings,
) -> AIProviderResult:
    if not settings.ai_provider_api_key:
        raise AIProviderError("AI provider is not configured")
    if settings.ai_provider_base_url_status != "configured":
        raise AIProviderError("AI provider base URL is invalid")

    payload = {
        "model": settings.ai_model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是 AI 装机助手的受控选型器。只能从用户提供的候选 component_id 中选择，"
                    "禁止编造任何硬件型号。必须只返回 json。"
                    "输出示例：{\"components\":{\"cpu\":\"候选CPU_ID\"},\"explanation\":\"中文说明\"}"
                ),
            },
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "budget": request.budget,
                        "use_case": request.use_case,
                        "preferences": request.preference_tokens,
                        "notes": request.notes,
                        "candidates": _candidate_payload(candidates_by_role, price_by_component_id),
                        "required_output": {
                            "components": {"role": "component_id"},
                            "explanation": "一句给用户看的中文说明",
                        },
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
            },
        ],
        "response_format": {"type": "json_object"},
        "thinking": {"type": "disabled"},
        "stream": False,
        "temperature": 0.2,
        "max_tokens": 800,
    }

    try:
        with httpx.Client(timeout=settings.ai_provider_timeout_seconds) as client:
            response = client.post(
                settings.ai_provider_chat_url,
                headers={
                    "Authorization": f"Bearer {settings.ai_provider_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        raise AIProviderError("AI provider request failed") from exc

    content = _message_content(data)
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError as exc:
        raise AIProviderError("AI provider returned invalid JSON") from exc

    components = parsed.get("components")
    explanation = parsed.get("explanation")
    if not isinstance(components, dict) or not isinstance(explanation, str):
        raise AIProviderError("AI provider returned invalid shape")

    normalized_components = {
        str(role): str(component_id)
        for role, component_id in components.items()
        if isinstance(role, str) and isinstance(component_id, str)
    }
    _validate_controlled_selection(normalized_components, candidates_by_role)
    return AIProviderResult(
        components=normalized_components,
        explanation=explanation[:500],
        actual_cost_cents=_actual_cost_cents(data),
    )


def _candidate_payload(
    candidates_by_role: Dict[str, List[HardwareComponent]],
    price_by_component_id: Dict[str, ComponentPrice],
) -> Dict[str, list]:
    return {
        role: [
            {
                "id": component.id,
                "name": component.name,
                "brand": component.brand,
                "price": price_by_component_id[component.id].reference_price,
                "specs": component.specs,
            }
            for component in candidates
            if component.id in price_by_component_id
        ]
        for role, candidates in candidates_by_role.items()
    }


def _message_content(data: dict) -> str:
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AIProviderError("AI provider returned no message content") from exc
    if not isinstance(content, str) or not content.strip():
        raise AIProviderError("AI provider returned empty message content")
    return content


def _validate_controlled_selection(
    components: Dict[str, str],
    candidates_by_role: Dict[str, List[HardwareComponent]],
) -> None:
    if not components:
        raise AIProviderError("AI provider returned empty selection")

    allowed_by_role = {
        role: {component.id for component in candidates}
        for role, candidates in candidates_by_role.items()
    }
    for role, component_id in components.items():
        if role not in allowed_by_role:
            raise AIProviderError("AI provider returned unknown role")
        if component_id not in allowed_by_role[role]:
            raise AIProviderError("AI provider returned component outside candidate pool")


def _actual_cost_cents(data: dict) -> int:
    usage = data.get("usage")
    if not isinstance(usage, dict):
        return 0
    cost = usage.get("cost_cents")
    return cost if isinstance(cost, int) and cost > 0 else 0
