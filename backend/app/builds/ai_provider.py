import json
from dataclasses import dataclass
from typing import Dict, List, Optional

import httpx

from app.builds.customization import condition_price, customized_budget_limit
from app.builds.models import BuildTemplate
from app.builds.service import BuildRequest, BuildTemplateDetails
from app.catalog.models import ComponentPrice, HardwareComponent
from app.core.config import Settings


class AIProviderError(Exception):
    pass


@dataclass(frozen=True)
class AIProviderResult:
    base_template_id: str
    patches: Dict[str, str]
    reasons: List[str]
    actual_cost_cents: int = 0


def select_build_with_deepseek(
    request: BuildRequest,
    base_candidates: List[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    settings: Settings,
    *,
    retry_feedback: Optional[str] = None,
) -> AIProviderResult:
    if not settings.ai_provider_api_key:
        raise AIProviderError("AI provider is not configured")
    if settings.ai_provider_base_url_status != "configured":
        raise AIProviderError("AI provider base URL is invalid")
    if not base_candidates:
        raise AIProviderError("No approved base templates are available")

    payload = {
        "model": settings.ai_model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是 AI 装机功能的受控配置优化器，不是配置生成器。"
                    "必须选择一个给定的 base_template_id，只能用 allowed_patches 中的 component_id 修改它。"
                    "禁止改变 fps/3A/均衡方向，禁止编造型号，禁止返回完整配置单。"
                    "内存容量、硬盘容量、Wi-Fi/蓝牙和自备显卡由服务器自动应用，禁止为这些硬需求返回补丁。"
                    "用户硬需求优先，最终价格必须在服务器给出的预算上限内。只返回 JSON。"
                ),
            },
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "request": _request_payload(request),
                        "budget_limit": customized_budget_limit(request),
                        "base_templates": _base_template_payload(base_candidates),
                        "allowed_patches": _patch_candidate_payload(
                            request,
                            components_by_id,
                            price_by_component_id,
                        ),
                        "retry_feedback": retry_feedback,
                        "required_output": {
                            "base_template_id": "必须来自 base_templates",
                            "patches": {"role": "allowed component_id；不改则为空对象"},
                            "reasons": ["1 到 3 条简短中文理由"],
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
        "temperature": 0.1,
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

    try:
        parsed = json.loads(_message_content(data))
    except json.JSONDecodeError as exc:
        raise AIProviderError("AI provider returned invalid JSON") from exc

    if not isinstance(parsed, dict) or set(parsed) != {
        "base_template_id",
        "patches",
        "reasons",
    }:
        raise AIProviderError("AI provider returned fields outside the patch-only schema")

    base_template_id = parsed.get("base_template_id")
    patches = parsed.get("patches")
    reasons = parsed.get("reasons")
    if (
        not isinstance(base_template_id, str)
        or not isinstance(patches, dict)
        or not isinstance(reasons, list)
        or not all(isinstance(reason, str) for reason in reasons)
    ):
        raise AIProviderError("AI provider returned invalid shape")

    allowed_template_ids = {template.id for template in base_candidates}
    if base_template_id not in allowed_template_ids:
        raise AIProviderError("AI provider returned an unknown base template")
    normalized_patches = _validate_patches(
        patches,
        request,
        components_by_id,
        price_by_component_id,
    )
    normalized_reasons = [reason.strip()[:160] for reason in reasons if reason.strip()][:3]
    if not normalized_reasons:
        raise AIProviderError("AI provider returned no reasons")
    return AIProviderResult(
        base_template_id=base_template_id,
        patches=normalized_patches,
        reasons=normalized_reasons,
        actual_cost_cents=_actual_cost_cents(data),
    )


def _request_payload(request: BuildRequest) -> dict:
    return {
        "budget": request.budget,
        "direction": request.direction,
        "use_case": request.use_case,
        "games": request.game_categories,
        "office_apps": request.office_apps,
        "purchase_preference": request.purchase_preference,
        "gpu_preference": request.gpu_preference,
        "ray_tracing": request.ray_tracing,
        "needs_wireless_network": request.needs_wireless_network,
        "memory_size": request.memory_size or "16GB",
        "storage_size": request.storage_size or "512GB",
        "owned_gpu_model": request.owned_gpu_model if request.no_gpu_build else None,
        "notes": request.notes,
    }


def _base_template_payload(templates: List[BuildTemplate]) -> List[dict]:
    payload = []
    for template in templates:
        details = BuildTemplateDetails.model_validate(template.details)
        payload.append(
            {
                "id": template.id,
                "target_budget": details.target_budget,
                "current_total": template.estimated_total,
                "direction": details.direction,
                "purchase_mode": details.purchase_mode,
                "gpu_vendor": details.gpu_vendor,
                "parts": [
                    {
                        "role": part.role,
                        "id": part.component_id,
                        "name": part.name,
                        "condition": part.condition,
                        "price": part.reference_price,
                        "specs": part.specs,
                    }
                    for part in details.parts
                ],
            }
        )
    return payload


def _patch_candidate_payload(
    request: BuildRequest,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> Dict[str, list]:
    fixed_roles = set()
    if request.memory_size:
        fixed_roles.add("ram")
    if request.storage_size:
        fixed_roles.add("storage")
    if request.no_gpu_build:
        fixed_roles.add("gpu")
    by_role: Dict[str, list] = {}
    for component in components_by_id.values():
        if component.category in fixed_roles:
            continue
        price = price_by_component_id.get(component.id)
        if (
            price is None
            or component.status != "active"
            or not component.is_recommended
        ):
            continue
        prices = {
            condition: value
            for condition in ("new", "used")
            if (value := condition_price(price, condition)) is not None
        }
        if not prices:
            continue
        by_role.setdefault(component.category, []).append(
            {
                "id": component.id,
                "name": component.name,
                "prices": prices,
                "specs": component.specs,
            }
        )
    for candidates in by_role.values():
        candidates.sort(key=lambda item: item["id"])
    return by_role


def _validate_patches(
    patches: dict,
    request: BuildRequest,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> Dict[str, str]:
    fixed_roles = {
        role
        for role, fixed in (
            ("ram", bool(request.memory_size)),
            ("storage", bool(request.storage_size)),
            ("gpu", request.no_gpu_build),
        )
        if fixed
    }
    normalized = {}
    for role, component_id in patches.items():
        if not isinstance(role, str) or not isinstance(component_id, str):
            raise AIProviderError("AI provider returned invalid patches")
        if role in fixed_roles:
            continue
        component = components_by_id.get(component_id)
        if (
            component is None
            or component.category != role
            or component.status != "active"
            or not component.is_recommended
            or component_id not in price_by_component_id
        ):
            raise AIProviderError("AI provider returned a patch outside the approved pool")
        normalized[role] = component_id
    return normalized


def _message_content(data: dict) -> str:
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AIProviderError("AI provider returned no message content") from exc
    if not isinstance(content, str) or not content.strip():
        raise AIProviderError("AI provider returned empty message content")
    return content


def _actual_cost_cents(data: dict) -> int:
    usage = data.get("usage")
    if not isinstance(usage, dict):
        return 0
    cost = usage.get("cost_cents")
    return cost if isinstance(cost, int) and cost > 0 else 0
