import re
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import list_components
from app.perf.generated_estimator import (
    generated_fps_limits,
    hardware_performance_score,
)


ReviewRiskLevel = Literal["pass", "warning", "error"]

ROLE_LABELS = {
    "cpu": "CPU",
    "gpu": "显卡",
    "motherboard": "主板",
    "ram": "内存",
    "storage": "硬盘",
    "psu": "电源",
}

REVIEW_ROLES = ["cpu", "gpu", "motherboard", "psu"]
SYSTEM_POWER_OVERHEAD_WATTS = 75
PSU_HEADROOM_FACTOR = 1.3
SEVERE_BOTTLENECK_PERCENT = 35


class ConfigReviewRequest(BaseModel):
    text: str = Field(min_length=12, max_length=5000)


class DetectedReviewComponent(BaseModel):
    role: str
    component_id: str
    name: str
    brand: str
    confidence: Literal["exact", "partial"]
    specs: Dict[str, Any] = Field(default_factory=dict)


class ReviewFinding(BaseModel):
    level: ReviewRiskLevel
    code: str
    title: str
    detail: str
    component_ids: List[str] = Field(default_factory=list)


class ConfigReviewResponse(BaseModel):
    risk_level: ReviewRiskLevel
    summary: str
    source_text: str
    seller_price: Optional[int]
    reference_total: Optional[int]
    detected_components: Dict[str, Optional[DetectedReviewComponent]]
    findings: List[ReviewFinding]
    questions_for_seller: List[str]
    reply_text: str


def analyze_configuration_text(session: Session, text: str) -> ConfigReviewResponse:
    normalized_text = _normalize(text)
    components = list_components(session)
    detected = _detect_components(normalized_text, components)
    findings = _build_findings(detected)
    questions = _questions_for_seller(detected, findings)
    risk_level = _overall_level(findings)
    summary = _summary_for_level(risk_level, findings)
    reply_text = _reply_text(summary, findings, questions)
    return ConfigReviewResponse(
        risk_level=risk_level,
        summary=summary,
        source_text=text,
        seller_price=None,
        reference_total=None,
        detected_components=detected,
        findings=findings,
        questions_for_seller=questions,
        reply_text=reply_text,
    )


def _detect_components(
    normalized_text: str,
    components: List[HardwareComponent],
) -> Dict[str, Optional[DetectedReviewComponent]]:
    detected: Dict[str, Optional[DetectedReviewComponent]] = {role: None for role in REVIEW_ROLES}
    for role in REVIEW_ROLES:
        candidates = [component for component in components if component.category == role]
        detected[role] = _best_match_for_role(normalized_text, candidates)
    return detected


def _best_match_for_role(
    normalized_text: str,
    candidates: List[HardwareComponent],
) -> Optional[DetectedReviewComponent]:
    best: Optional[DetectedReviewComponent] = None
    best_score = 0
    for component in candidates:
        aliases = _component_aliases(component)
        score = 0
        confidence: Literal["exact", "partial"] = "partial"
        for alias in aliases:
            if not alias or len(alias) < 3:
                continue
            if alias in normalized_text:
                score = max(score, len(alias))
                if alias in {_normalize(component.id), _normalize(component.name)}:
                    confidence = "exact"
        if score > best_score:
            best_score = score
            best = DetectedReviewComponent(
                role=component.category,
                component_id=component.id,
                name=component.name,
                brand=component.brand,
                confidence=confidence,
                specs=component.specs,
            )
    return best


def _component_aliases(component: HardwareComponent) -> List[str]:
    aliases = [
        _normalize(component.id),
        _normalize(component.name),
        _normalize(component.detail_raw),
    ]
    aliases.extend(_normalized_tokens(component.id))
    aliases.extend(_normalized_tokens(component.name))
    aliases.extend(_normalized_tokens(component.detail_raw))
    for value in component.specs.values():
        if isinstance(value, str):
            aliases.append(_normalize(value))
            aliases.extend(_normalized_tokens(value))
    return aliases


def _build_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    findings.extend(_missing_core_findings(detected))
    findings.extend(_insufficient_information_findings(detected))
    findings.extend(_bottleneck_findings(detected))
    findings.extend(_motherboard_power_findings(detected))
    findings.extend(_psu_findings(detected))
    return findings


def _insufficient_information_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    missing_roles = [
        role
        for role in ["cpu", "gpu", "motherboard", "psu"]
        if detected.get(role) is None
    ]
    if len(missing_roles) < 2:
        return []
    labels = "、".join(ROLE_LABELS[role] for role in missing_roles)
    return [
        ReviewFinding(
            level="error",
            code="insufficient_core_information",
            title="核心型号信息不足",
            detail=f"{labels} 都没有明确型号，无法判断电源余量和性能瓶颈，请先补全。",
        )
    ]


def _missing_core_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    for role in ["cpu", "gpu", "motherboard", "psu"]:
        if detected.get(role) is None:
            findings.append(
                ReviewFinding(
                    level="warning",
                    code=f"missing_{role}",
                    title=f"{ROLE_LABELS[role]}型号不明确",
                    detail=f"配置单里没有识别到明确的{ROLE_LABELS[role]}型号，需要商家补充完整后再判断。",
                )
            )
    return findings


def _bottleneck_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    gpu = detected.get("gpu")
    if cpu is None or gpu is None:
        return []
    cpu_score = hardware_performance_score(
        cpu.component_id,
        "cpu",
        cpu.name,
        cpu.specs,
    )
    gpu_score = hardware_performance_score(
        gpu.component_id,
        "gpu",
        gpu.name,
        gpu.specs,
    )
    if cpu_score is None or gpu_score is None:
        return [
            ReviewFinding(
                level="warning",
                code="bottleneck_data_missing",
                title="暂时无法判断性能瓶颈",
                detail=f"{cpu.name} 或 {gpu.name} 缺少 FPS 模型所需的性能数据。",
                component_ids=[cpu.component_id, gpu.component_id],
            )
        ]
    cpu_limit, gpu_limit = generated_fps_limits(
        "pubg",
        "2k",
        cpu_score,
        gpu_score,
    )
    larger_limit = max(cpu_limit, gpu_limit)
    gap_percent = round(abs(cpu_limit - gpu_limit) / larger_limit * 100)
    component_ids = [cpu.component_id, gpu.component_id]
    if gap_percent < SEVERE_BOTTLENECK_PERCENT:
        return [
            ReviewFinding(
                level="pass",
                code="cpu_gpu_balanced",
                title="CPU 和显卡搭配合理",
                detail=f"按 2K 综合游戏估算，{cpu.name} 和 {gpu.name} 没有明显性能失衡。",
                component_ids=component_ids,
            )
        ]
    if cpu_limit < gpu_limit:
        return [
            ReviewFinding(
                level="warning",
                code="cpu_bottleneck",
                title="CPU 可能形成明显瓶颈",
                detail=f"按 2K 综合游戏估算，{cpu.name} 比 {gpu.name} 能支撑的帧数上限低约 {gap_percent}%，高帧率游戏可能被 CPU 拖住。",
                component_ids=component_ids,
            )
        ]
    return [
        ReviewFinding(
            level="warning",
            code="gpu_bottleneck",
            title="显卡可能形成明显瓶颈",
            detail=f"按 2K 综合游戏估算，{gpu.name} 比 {cpu.name} 能支撑的帧数上限低约 {gap_percent}%，CPU 的一部分游戏性能可能发挥不出来。",
            component_ids=component_ids,
        )
    ]


def _motherboard_power_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    motherboard = detected.get("motherboard")
    if cpu is None or motherboard is None:
        return []
    cpu_power = _int_spec(cpu, "tdp")
    motherboard_limit = _int_spec(motherboard, "cpu_power_limit")
    component_ids = [cpu.component_id, motherboard.component_id]
    if not cpu_power or not motherboard_limit:
        return [
            ReviewFinding(
                level="warning",
                code="motherboard_power_data_missing",
                title="主板供电数据待补充",
                detail=f"已识别 {motherboard.name}，但缺少它的持续供电上限，暂时不能判断能否带动 {cpu.name}。",
                component_ids=component_ids,
            )
        ]
    if motherboard_limit < cpu_power:
        return [
            ReviewFinding(
                level="error",
                code="motherboard_power_insufficient",
                title="主板供电可能带不动 CPU",
                detail=f"{cpu.name} 峰值功耗约 {cpu_power}W，{motherboard.name} 持续供电上限约 {motherboard_limit}W，可能降频或不稳定。",
                component_ids=component_ids,
            )
        ]
    return [
        ReviewFinding(
            level="pass",
            code="motherboard_power_ok",
            title="主板供电可以带动 CPU",
            detail=f"{motherboard.name} 持续供电上限约 {motherboard_limit}W，可以覆盖 {cpu.name} 约 {cpu_power}W 的峰值功耗。",
            component_ids=component_ids,
        )
    ]


def _psu_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    psu = detected.get("psu")
    if psu is None:
        return []
    psu_watt = _int_spec(psu, "watt")
    component_power = sum(
        _int_spec(component, "tdp")
        for role, component in detected.items()
        if role != "psu" and component is not None
    )
    if not psu_watt or not component_power:
        return [
            ReviewFinding(
                level="warning",
                code="psu_power_data_missing",
                title="暂时无法判断电源余量",
                detail="电源瓦数或主要配件功耗数据不完整，暂时无法判断是否带得动。",
                component_ids=[psu.component_id],
            )
        ]
    total_power = component_power + SYSTEM_POWER_OVERHEAD_WATTS
    recommended_watt = round(total_power * PSU_HEADROOM_FACTOR)
    if psu_watt < total_power:
        level: ReviewRiskLevel = "error"
        code = "psu_wattage_insufficient"
        title = "电源瓦数不够"
        detail = f"整机峰值功耗估算约 {total_power}W，{psu_watt}W 电源可能带不动。"
    elif psu_watt < recommended_watt:
        level = "warning"
        code = "psu_wattage_tight"
        title = "电源余量偏紧"
        detail = f"整机峰值功耗估算约 {total_power}W，建议预留约 30% 余量，电源最好达到 {recommended_watt}W 左右。"
    else:
        level = "pass"
        code = "psu_wattage_ok"
        title = "电源余量充足"
        detail = f"整机峰值功耗估算约 {total_power}W，{psu_watt}W 电源有足够基础余量。"
    return [
        ReviewFinding(
            level=level,
            code=code,
            title=title,
            detail=detail,
            component_ids=[psu.component_id],
        )
    ]


def _questions_for_seller(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    findings: List[ReviewFinding],
) -> List[str]:
    questions: List[str] = []
    for role in ["cpu", "gpu", "motherboard", "psu"]:
        if detected.get(role) is None:
            questions.append(f"请问{ROLE_LABELS[role]}的完整品牌和型号是什么？")
    return questions[:5]


def _overall_level(findings: List[ReviewFinding]) -> ReviewRiskLevel:
    if any(finding.level == "error" for finding in findings):
        return "error"
    if any(finding.level == "warning" for finding in findings):
        return "warning"
    return "pass"


def _summary_for_level(level: ReviewRiskLevel, findings: List[ReviewFinding]) -> str:
    if any(finding.code == "insufficient_core_information" for finding in findings):
        return "信息不足，不建议直接买。先让商家补全核心配件的具体品牌和型号。"
    if level == "error":
        return "不建议直接使用。这套配置的电源或主板供电可能带不动对应硬件，需要先调整。"
    if level == "warning":
        return "这套配置可以运行，但电源余量、主板供电数据或 CPU/显卡搭配存在需要注意的问题。"
    return "整机电源、主板供电和 CPU/显卡搭配都没有发现明显问题。"


def _reply_text(
    summary: str,
    findings: List[ReviewFinding],
    questions: List[str],
) -> str:
    problem_titles = "、".join(
        finding.title for finding in findings if finding.level in {"error", "warning"}
    )
    question_text = "；".join(questions)
    if problem_titles:
        suffix = f" {question_text}" if question_text else ""
        return f"{summary} 我主要担心：{problem_titles}。{suffix}".strip()
    return f"{summary} {question_text}".strip()


def _int_spec(component: DetectedReviewComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0


def _normalize(value: str) -> str:
    return re.sub(r"[^0-9a-zA-Z\u4e00-\u9fff]+", "", value).lower()


def _normalized_tokens(value: str) -> List[str]:
    tokens = [
        _normalize(token)
        for token in re.split(r"[^0-9a-zA-Z\u4e00-\u9fff]+", value)
        if token
    ]
    aliases: List[str] = []
    for token in tokens:
        if len(token) >= 3:
            aliases.append(token)
        if len(token) >= 4 and token[-1] == "m" and any(char.isdigit() for char in token):
            aliases.append(token[:-1])
    return aliases
