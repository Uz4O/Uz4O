import re
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import list_components
from app.catalog.rule_specs import (
    CPU_GPU_PAIRING_TIER,
    GPU_PAIRING_TIER,
    SPECIAL_5600_CPU_IDS,
    is_cpu_gpu_pairing_allowed,
    psu_supports_gpu_power_connector,
    recommended_psu_watt_for_specs,
)
from app.core.config import Settings
from app.review.web_enrichment import WebEnrichmentSource, enrich_component_from_web


ReviewRiskLevel = Literal["pass", "warning", "error"]
ReviewDirection = Literal["fps", "aaa", "balanced", "office"]
ReviewResolution = Literal["1080p", "1440p", "2160p"]
ReviewConfidence = Literal["high", "medium", "low", "unavailable"]
ReviewRatingStatus = Literal["graded", "failed", "incomplete"]
ReviewRecommendationSeverity = Literal["required", "recommended", "optional"]
WebSearchStatus = Literal["not_needed", "completed", "partial", "unavailable"]

ROLE_LABELS = {
    "cpu": "CPU",
    "gpu": "显卡",
    "motherboard": "主板",
    "ram": "内存",
    "storage": "硬盘",
    "psu": "电源",
}

REVIEW_ROLES = ["cpu", "gpu", "motherboard", "ram", "storage", "psu"]
REQUIRED_PAIRING_ROLES = ["cpu", "gpu", "motherboard", "ram", "psu"]
WEB_ENRICHMENT_ROLES = ["cpu", "gpu", "motherboard", "psu", "ram", "storage"]
CRITICAL_SPEC_KEYS = {
    "cpu": {"socket", "tdp"},
    "gpu": {"tdp"},
    "motherboard": {"socket", "mem_type"},
    "ram": {"type"},
    "storage": set(),
    "psu": {"watt"},
}


class ConfigReviewRequest(BaseModel):
    text: str = Field(min_length=12, max_length=5000)


class DetectedReviewComponent(BaseModel):
    role: str
    component_id: str
    name: str
    brand: str
    confidence: Literal["exact", "partial", "web"]
    specs: Dict[str, Any] = Field(default_factory=dict)


class ReviewFinding(BaseModel):
    level: ReviewRiskLevel
    code: str
    title: str
    detail: str
    component_ids: List[str] = Field(default_factory=list)


class ReviewRating(BaseModel):
    status: ReviewRatingStatus
    score: Optional[int] = Field(default=None, ge=0, le=100)
    grade: Optional[Literal["C", "B", "A", "S"]] = None
    detail: str
    confidence: ReviewConfidence


class ReviewRecommendation(BaseModel):
    severity: ReviewRecommendationSeverity
    title: str
    reason: str
    action: str
    expected_impact: str
    component_ids: List[str] = Field(default_factory=list)


class ReviewEvidenceSource(BaseModel):
    role: str
    component_name: str
    title: str
    url: str


class ConfigReviewResponse(BaseModel):
    risk_level: ReviewRiskLevel
    summary: str
    source_text: str
    direction: ReviewDirection
    resolution: ReviewResolution
    pairing_rating: ReviewRating
    performance_rating: ReviewRating
    detected_components: Dict[str, Optional[DetectedReviewComponent]]
    findings: List[ReviewFinding]
    recommendations: List[ReviewRecommendation]
    questions_for_seller: List[str]
    reply_text: str
    web_search_status: WebSearchStatus
    web_sources: List[ReviewEvidenceSource] = Field(default_factory=list)


def analyze_configuration_text(
    session: Session,
    text: str,
    settings: Optional[Settings] = None,
) -> ConfigReviewResponse:
    normalized_text = _normalize(text)
    components = list_components(session)
    detected = _detect_components(normalized_text, components)
    web_search_status, web_sources = _enrich_detected_components(
        detected,
        text,
        settings,
    )
    findings = _build_findings(detected, normalized_text)
    recommendations = _build_recommendations(findings, detected)
    questions = _questions_for_seller(detected, findings)
    risk_level = _overall_level(findings)
    summary = _summary_for_level(risk_level, findings)
    reply_text = _reply_text(summary, findings, questions)
    return ConfigReviewResponse(
        risk_level=risk_level,
        summary=summary,
        source_text=text,
        # Kept at neutral legacy values so already-released clients can still decode the response.
        direction="balanced",
        resolution="1440p",
        pairing_rating=_pairing_rating(detected, findings),
        performance_rating=_performance_rating(detected),
        detected_components=detected,
        findings=findings,
        recommendations=recommendations,
        questions_for_seller=questions,
        reply_text=reply_text,
        web_search_status=web_search_status,
        web_sources=web_sources,
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


def _enrich_detected_components(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    source_text: str,
    settings: Optional[Settings],
) -> tuple[WebSearchStatus, List[ReviewEvidenceSource]]:
    labeled_queries = _labeled_component_queries(source_text)
    requests: List[tuple[str, str]] = []
    for role in WEB_ENRICHMENT_ROLES:
        component = detected.get(role)
        if component is None:
            query = labeled_queries.get(role)
        elif CRITICAL_SPEC_KEYS[role] - component.specs.keys():
            query = component.name
        else:
            query = None
        if query:
            requests.append((role, query))

    if not requests:
        return "not_needed", []
    if settings is None or not settings.review_search_api_key or not settings.ai_provider_api_key:
        return "unavailable", []

    evidence: List[ReviewEvidenceSource] = []
    completed = 0
    # ponytail: cap synchronous enrichment until latency telemetry justifies batching.
    for role, query in requests[:3]:
        result = enrich_component_from_web(query, role, settings)
        if result is None:
            continue
        completed += 1
        component = detected.get(role)
        if component is None:
            component = DetectedReviewComponent(
                role=role,
                component_id=f"web-{role}-{_normalize(result.name)[:80]}",
                name=result.name,
                brand=result.brand,
                confidence="web",
                specs=result.specs,
            )
            detected[role] = component
        else:
            component.specs = {**result.specs, **component.specs}
            component.confidence = "web"
        evidence.extend(_evidence_sources(role, component.name, result.sources))

    if completed == 0:
        return "unavailable", []
    return ("completed" if completed == len(requests) else "partial"), evidence


def _labeled_component_queries(text: str) -> Dict[str, str]:
    label_roles = {
        "cpu": "cpu",
        "处理器": "cpu",
        "gpu": "gpu",
        "显卡": "gpu",
        "主板": "motherboard",
        "内存": "ram",
        "硬盘": "storage",
        "ssd": "storage",
        "电源": "psu",
    }
    queries: Dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"\s*([^:：]{1,8})\s*[:：]\s*([^,，\n]{2,160})", line, re.IGNORECASE)
        if not match:
            continue
        role = label_roles.get(match.group(1).strip().lower())
        query = match.group(2).strip()
        if role and any(character.isdigit() for character in query):
            queries[role] = query
    return queries


def _evidence_sources(
    role: str,
    component_name: str,
    sources: List[WebEnrichmentSource],
) -> List[ReviewEvidenceSource]:
    return [
        ReviewEvidenceSource(
            role=role,
            component_name=component_name,
            title=source.title,
            url=source.url,
        )
        for source in sources
    ]


def _build_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    normalized_text: str,
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    findings.extend(_missing_core_findings(detected))
    findings.extend(_insufficient_information_findings(detected))
    findings.extend(_marketing_findings(detected, normalized_text))
    findings.extend(_outdated_clearance_findings(detected, normalized_text))
    findings.extend(_balance_findings(detected))
    findings.extend(_motherboard_findings(detected))
    findings.extend(_platform_findings(detected))
    findings.extend(_ram_findings(detected, normalized_text))
    findings.extend(_storage_findings(detected))
    findings.extend(_psu_findings(detected))
    if not findings:
        findings.append(
            ReviewFinding(
                level="pass",
                code="basic_review_passed",
                title="未发现明显排雷点",
                detail="已识别到的配置没有发现明显硬伤，但仍建议让商家写清楚每个配件的具体品牌和型号。",
            )
        )
    return findings


def _insufficient_information_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    missing_roles = [
        role for role in REQUIRED_PAIRING_ROLES if detected.get(role) is None
    ]
    if len(missing_roles) < 2:
        return []
    labels = "、".join(ROLE_LABELS[role] for role in missing_roles)
    return [
        ReviewFinding(
            level="error",
            code="insufficient_core_information",
            title="核心型号信息不足",
            detail=f"{labels} 都没有明确型号，无法完整判断兼容性、功耗和性能，建议先让商家补全。",
        )
    ]


def _marketing_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    normalized_text: str,
) -> List[ReviewFinding]:
    marketing_terms = [
        "i7级",
        "i9级",
        "电竞级",
        "高端独显",
        "高性能显卡",
        "游戏显卡",
        "军工主板",
        "高性能游戏主机",
    ]
    matched_terms = [term for term in marketing_terms if _normalize(term) in normalized_text]
    if not matched_terms:
        return []
    missing_labels = [
        ROLE_LABELS[role]
        for role in ["cpu", "gpu", "motherboard"]
        if detected.get(role) is None
    ]
    if not missing_labels:
        return []
    return [
        ReviewFinding(
            level="error",
            code="marketing_terms_without_models",
            title="营销话术替代具体型号",
            detail=f"配置单使用了{'、'.join(matched_terms)}这类听起来高级但不等于型号的话术，且{'、'.join(missing_labels)}没有写清楚。",
        )
    ]


def _outdated_clearance_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    normalized_text: str,
) -> List[ReviewFinding]:
    risky_components = [
        component
        for component in detected.values()
        if component is not None and _is_outdated_clearance_component(component)
    ]
    if not risky_components:
        return []
    level: ReviewRiskLevel = "error" if _looks_sold_as_performance_build(normalized_text) else "warning"
    names = "、".join(component.name for component in risky_components)
    detail = (
        f"{names} 属于明显老旧或清库存硬件，却被包装成高性能/游戏主机，风险很高。"
        if level == "error"
        else f"{names} 属于明显老旧或清库存硬件，购买前要确认是否真能满足用途。"
    )
    return [
        ReviewFinding(
            level=level,
            code="outdated_clearance_hardware",
            title="老旧清库存硬件风险",
            detail=detail,
            component_ids=[component.component_id for component in risky_components],
        )
    ]


def _missing_core_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    for role in REQUIRED_PAIRING_ROLES:
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


def _balance_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    gpu = detected.get("gpu")
    if cpu is None or gpu is None:
        return []
    cpu_perf = _int_spec(cpu, "perf_index")
    gpu_perf = _int_spec(gpu, "perf_index")
    is_reviewed_pair = (
        cpu.component_id in CPU_GPU_PAIRING_TIER or cpu.component_id in SPECIAL_5600_CPU_IDS
    ) and gpu.component_id in GPU_PAIRING_TIER
    if is_reviewed_pair and not is_cpu_gpu_pairing_allowed(cpu.component_id, gpu.component_id):
        if cpu_perf >= gpu_perf:
            return [
                ReviewFinding(
                    level="error",
                    code="cpu_gpu_imbalance",
                    title="CPU 与显卡档次不匹配",
                    detail=_cpu_heavy_pairing_detail(cpu.name, gpu.name),
                    component_ids=[cpu.component_id, gpu.component_id],
                )
            ]
        return [
            ReviewFinding(
                level="error",
                code="gpu_cpu_imbalance",
                title="CPU 与显卡档次不匹配",
                detail=_gpu_heavy_pairing_detail(cpu.name, gpu.name),
                component_ids=[cpu.component_id, gpu.component_id],
            )
        ]
    if cpu_perf > 0 and gpu_perf > 0 and cpu_perf >= gpu_perf * 1.6:
        return [
            ReviewFinding(
                level="error",
                code="cpu_gpu_imbalance",
                title="CPU 偏高，显卡偏弱",
                detail=_cpu_heavy_pairing_detail(cpu.name, gpu.name),
                component_ids=[cpu.component_id, gpu.component_id],
            )
        ]
    if cpu_perf > 0 and gpu_perf > 0 and gpu_perf >= cpu_perf * 1.8:
        return [
            ReviewFinding(
                level="warning",
                code="gpu_cpu_imbalance",
                title="显卡很强，CPU 偏弱",
                detail=_gpu_heavy_pairing_detail(cpu.name, gpu.name),
                component_ids=[cpu.component_id, gpu.component_id],
            )
        ]
    return []


def _cpu_heavy_pairing_detail(cpu_name: str, gpu_name: str) -> str:
    return f"{cpu_name} 明显强于 {gpu_name}，显卡性能相对偏弱，当前搭配会让显卡成为主要短板。"


def _gpu_heavy_pairing_detail(cpu_name: str, gpu_name: str) -> str:
    return f"{gpu_name} 明显强于 {cpu_name}，CPU 性能相对偏弱，当前搭配可能无法充分发挥显卡。"


def _motherboard_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    motherboard = detected.get("motherboard")
    if cpu is None or motherboard is None:
        return []
    chipset = str(motherboard.specs.get("chipset", motherboard.name)).upper()
    if _int_spec(cpu, "perf_index") >= 90 and chipset.startswith(("H", "A")):
        return [
            ReviewFinding(
                level="warning",
                code="low_end_board_for_i7",
                title="主板档次偏保守",
                detail=f"{motherboard.name} 属于入门主板，搭配 {cpu.name} 这种高功耗 CPU 时，长期满载和扩展性都不理想。",
                component_ids=[cpu.component_id, motherboard.component_id],
            )
        ]
    return []


def _platform_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    cpu = detected.get("cpu")
    motherboard = detected.get("motherboard")
    if cpu is not None and motherboard is not None:
        cpu_socket = _string_spec(cpu, "socket")
        motherboard_socket = _string_spec(motherboard, "socket")
        if cpu_socket and motherboard_socket and cpu_socket != motherboard_socket:
            findings.append(
                ReviewFinding(
                    level="error",
                    code="cpu_motherboard_socket",
                    title="CPU 和主板插槽不匹配",
                    detail=f"{cpu.name} 是 {cpu_socket}，{motherboard.name} 是 {motherboard_socket}。",
                    component_ids=[cpu.component_id, motherboard.component_id],
                )
            )

    ram = detected.get("ram")
    if motherboard is not None and ram is not None:
        motherboard_type = _string_spec(motherboard, "mem_type")
        ram_type = _string_spec(ram, "type")
        if motherboard_type and ram_type and motherboard_type.upper() != ram_type.upper():
            findings.append(
                ReviewFinding(
                    level="error",
                    code="motherboard_ram_type",
                    title="主板和内存代际不匹配",
                    detail=f"{motherboard.name} 需要 {motherboard_type}，但当前内存是 {ram_type}。",
                    component_ids=[motherboard.component_id, ram.component_id],
                )
            )
    return findings


def _ram_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    normalized_text: str,
) -> List[ReviewFinding]:
    ram = detected.get("ram")
    if ram is None:
        return []
    findings: List[ReviewFinding] = []
    capacity_gb = _int_spec(ram, "capacity_gb")
    if 0 < capacity_gb < 16:
        findings.append(
            ReviewFinding(
                level="warning",
                code="ram_capacity_low",
                title="内存容量偏小",
                detail=f"当前识别为 {capacity_gb}GB 内存，日常游戏和多任务容易较早触及容量上限。",
                component_ids=[ram.component_id],
            )
        )
    if any(marker in normalized_text for marker in ["单条", "1x8", "1x16", "1x32"]):
        findings.append(
            ReviewFinding(
                level="warning",
                code="ram_single_channel",
                title="内存可能是单通道",
                detail="配置单写的是单条内存，部分游戏和核显场景会损失带宽与帧率稳定性。",
                component_ids=[ram.component_id],
            )
        )
    return findings


def _storage_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    storage = detected.get("storage")
    if storage is None:
        return []
    capacity_gb = _int_spec(storage, "capacity_gb")
    if 0 < capacity_gb < 512:
        return [
            ReviewFinding(
                level="warning",
                code="storage_capacity_low",
                title="硬盘容量偏小",
                detail=f"当前识别为 {capacity_gb}GB，安装系统和常用软件后留给游戏或项目文件的空间会比较有限。",
                component_ids=[storage.component_id],
            )
        ]
    return []


def _psu_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    gpu = detected.get("gpu")
    psu = detected.get("psu")
    if cpu is None or gpu is None or psu is None:
        return []
    findings: List[ReviewFinding] = []
    psu_watt = _int_spec(psu, "watt")
    cpu_tdp = _int_spec(cpu, "tdp")
    gpu_tdp = _int_spec(gpu, "tdp")
    if psu_watt and cpu_tdp and gpu_tdp:
        recommended_watt = recommended_psu_watt_for_specs(
            cpu_tdp,
            gpu.component_id,
            gpu_tdp,
        )
        if psu_watt < recommended_watt:
            findings.append(
                ReviewFinding(
                    level="error",
                    code="psu_wattage_insufficient",
                    title="电源瓦数不够",
                    detail=f"这套配置推荐至少使用 {recommended_watt}W 电源，当前 {psu_watt}W 不足。",
                    component_ids=[psu.component_id],
                )
            )
        elif not psu_supports_gpu_power_connector(gpu.component_id, psu.specs):
            findings.append(
                ReviewFinding(
                    level="error",
                    code="psu_connector_insufficient",
                    title="显卡供电接口不满足要求",
                    detail="当前电源缺少显卡需要的原生 600W 12V-2x6 供电路径。",
                    component_ids=[psu.component_id],
                )
            )
    if psu.brand in {"未知", "Unknown", ""}:
        findings.append(
            ReviewFinding(
                level="warning",
                code="psu_model_unclear",
                title="电源品牌型号不明确",
                detail="配置单只写了电源瓦数，没有可靠品牌、具体型号和认证信息，整机风险主要会集中在这里。",
                component_ids=[psu.component_id],
            )
        )
    return findings


def _build_recommendations(
    findings: List[ReviewFinding],
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewRecommendation]:
    recommendations: List[ReviewRecommendation] = []
    has_insufficient_information = any(
        finding.code == "insufficient_core_information" for finding in findings
    )
    for finding in findings:
        if has_insufficient_information and finding.code.startswith("missing_"):
            continue
        severity: ReviewRecommendationSeverity = (
            "required"
            if finding.level == "error" or finding.code.startswith("missing_")
            else "optional"
            if finding.level == "pass"
            else "recommended"
        )
        title, action, impact = _recommendation_copy(finding, detected)
        recommendations.append(
            ReviewRecommendation(
                severity=severity,
                title=title,
                reason=finding.detail,
                action=action,
                expected_impact=impact,
                component_ids=finding.component_ids,
            )
        )
    return recommendations


def _recommendation_copy(
    finding: ReviewFinding,
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> tuple[str, str, str]:
    code = finding.code
    if code == "insufficient_core_information" or code.startswith("missing_"):
        return (
            "补全核心配件型号",
            "先让商家补充缺失配件的完整品牌和型号，再重新评估。",
            "补全后才能可靠检查插槽、内存代际、供电和性能搭配。",
        )
    if code == "marketing_terms_without_models":
        return (
            "把营销名称改成具体型号",
            "要求商家逐项写明 CPU、显卡和主板的完整型号，不接受“i7 级”“电竞级”等替代写法。",
            "避免用模糊话术掩盖低规格或老旧配件。",
        )
    if code == "outdated_clearance_hardware":
        return (
            "替换老旧硬件",
            "保留其余已明确且兼容的配件，只替换清单中标出的老旧 CPU、显卡或平台后重新评估。",
            "降低旧平台性能、功耗、保修和后续升级受限的风险。",
        )
    if code in {"cpu_gpu_imbalance", "gpu_cpu_imbalance"}:
        if code == "cpu_gpu_imbalance":
            action = "保留主板、内存等其余配件，优先把显卡提升到与 CPU 接近的档次；若不需要当前 CPU 性能，则只降低 CPU 一档。"
        else:
            action = "保留主板、内存等其余配件，优先把 CPU 提升到能带动当前显卡的档次；若目标性能不需要这张显卡，则只降低显卡一档。"
        return (
            "缩小 CPU 与显卡的档次差距",
            action,
            "让 CPU 与显卡的性能档次更协调，并减少明显短板。",
        )
    if code == "low_end_board_for_i7":
        return (
            "更换同平台的合适主板",
            "CPU、内存和显卡保持不变，只把主板换成插槽和内存代际相同、供电与扩展更适合该 CPU 的型号。",
            "改善高负载稳定性和扩展空间，不改变整个平台。",
        )
    if code == "cpu_motherboard_socket":
        return (
            "统一 CPU 与主板插槽",
            "只更换 CPU 或主板其中一件，使两者插槽完全一致；更换后再次核对内存代际。",
            "消除无法安装和开机的硬性兼容问题。",
        )
    if code == "motherboard_ram_type":
        motherboard = detected.get("motherboard")
        memory_type = _string_spec(motherboard, "mem_type") if motherboard is not None else "主板要求的代际"
        return (
            "统一主板与内存代际",
            f"若保留当前主板，只把内存更换为 {memory_type}；不要混用 DDR4 与 DDR5。",
            "消除内存无法安装和使用的硬性兼容问题。",
        )
    if code == "psu_wattage_insufficient":
        return (
            "更换满足功耗要求的电源",
            "其余配件保持不变，只把电源换成达到建议瓦数、且显卡供电接口齐全的明确型号。",
            "降低高负载关机、重启和供电不稳定风险。",
        )
    if code == "psu_connector_insufficient":
        return (
            "更换接口合规的电源",
            "其余配件保持不变，只换成带原生 12V-2x6 600W 供电线、规格明确的 ATX 3.0 或更新电源。",
            "避免转接线和接口能力不足带来的供电风险。",
        )
    if code == "psu_model_unclear":
        return (
            "确认或更换明确型号的电源",
            "先让商家给出电源完整品牌、型号、额定功率和显卡接口；无法确认时只更换电源。",
            "让供电能力和售后信息可核验。",
        )
    if code == "ram_capacity_low":
        return (
            "把内存补到至少 16GB",
            "保留平台和其他配件，只增加同规格内存或换成容量不少于 16GB 的兼容套装。",
            "减少多任务和游戏中的内存不足与卡顿。",
        )
    if code == "ram_single_channel":
        return (
            "改为双通道内存",
            "保留总容量目标，改用两条匹配规格的内存组成双通道。",
            "提高内存带宽和帧率稳定性。",
        )
    if code == "storage_capacity_low":
        return (
            "确认硬盘容量是否够用",
            "其他配件保持不变，只在确有容量需求时把系统盘调整到至少 512GB。",
            "减少系统、软件与游戏安装空间不足的问题。",
        )
    return (
        "购买前复核完整型号",
        "保留当前搭配，要求商家把每个配件的完整品牌、型号和保修方式写进配置单。",
        "让最终交付配置与评估对象一致。",
    )


def _questions_for_seller(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    findings: List[ReviewFinding],
) -> List[str]:
    questions: List[str] = []
    if detected.get("psu") is None or any(finding.code == "psu_model_unclear" for finding in findings):
        questions.append("请问电源的具体品牌和型号是什么？有没有 80Plus 认证？")
    for role in ["cpu", "gpu", "motherboard", "ram", "storage"]:
        if detected.get(role) is None:
            questions.append(f"请问{ROLE_LABELS[role]}的完整品牌和型号是什么？")
    if not questions:
        questions.append("请把每个配件的完整品牌、型号和保修方式写在配置单里。")
    return questions[:5]


def _pairing_rating(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    findings: List[ReviewFinding],
) -> ReviewRating:
    hard_failure_codes = {
        "cpu_motherboard_socket",
        "motherboard_ram_type",
        "psu_wattage_insufficient",
        "psu_connector_insufficient",
    }
    hard_failures = [finding for finding in findings if finding.code in hard_failure_codes]
    if hard_failures:
        return ReviewRating(
            status="failed",
            detail="存在无法安装、无法正常使用或供电不足的硬性问题，必须修改后再考虑。",
            confidence=_component_confidence(
                detected,
                [role for role in REQUIRED_PAIRING_ROLES if detected.get(role) is not None],
            ),
        )

    missing_roles = [
        role for role in REQUIRED_PAIRING_ROLES if detected.get(role) is None
    ]
    if missing_roles:
        return ReviewRating(
            status="incomplete",
            detail=f"缺少{'、'.join(ROLE_LABELS[role] for role in missing_roles)}，暂时无法完整评分。",
            confidence="unavailable",
        )

    rating_penalties = {
        "cpu_gpu_imbalance": 45,
        "gpu_cpu_imbalance": 45,
        "low_end_board_for_i7": 20,
        "psu_model_unclear": 15,
        "ram_capacity_low": 10,
        "ram_single_channel": 10,
        "storage_capacity_low": 5,
    }
    score = max(0, 100 - sum(rating_penalties.get(finding.code, 0) for finding in findings))
    confidence = _component_confidence(detected, REQUIRED_PAIRING_ROLES)
    return ReviewRating(
        status="graded",
        score=score,
        grade=_rating_grade(score),
        detail="该等级综合兼容性、供电、CPU/显卡档次及已识别的内存和存储搭配。",
        confidence=confidence,
    )


def _performance_rating(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> ReviewRating:
    cpu = detected.get("cpu")
    gpu = detected.get("gpu")
    cpu_perf = _int_spec(cpu, "perf_index") if cpu is not None else 0
    gpu_perf = _int_spec(gpu, "perf_index") if gpu is not None else 0
    if cpu_perf <= 0 or gpu_perf <= 0:
        return ReviewRating(
            status="incomplete",
            detail="CPU 或显卡缺少可比较的性能数据，暂时无法评级。",
            confidence="unavailable",
        )

    score = round(min(cpu_perf, gpu_perf) * 0.6 + (cpu_perf + gpu_perf) * 0.2)
    score = max(0, min(100, score))
    return ReviewRating(
        status="graded",
        score=score,
        grade=_rating_grade(score),
        detail="该等级综合 CPU 与显卡性能，并对明显短板降低评价；不代表具体游戏帧数。",
        confidence=_component_confidence(detected, ["cpu", "gpu"]),
    )


def _component_confidence(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    roles: List[str],
) -> ReviewConfidence:
    components = [detected.get(role) for role in roles]
    if any(component is None for component in components):
        return "unavailable"
    if any(component is not None and component.confidence == "web" for component in components):
        return "low"
    if any(component is not None and component.confidence == "partial" for component in components):
        return "medium"
    if any(
        component is not None and CRITICAL_SPEC_KEYS[component.role] - component.specs.keys()
        for component in components
    ):
        return "low"
    return "high"


def _rating_grade(score: int) -> str:
    if score >= 90:
        return "S"
    if score >= 75:
        return "A"
    if score >= 60:
        return "B"
    return "C"


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
        return "不建议直接买。这张配置单存在比较明显的风险点，需要让商家改清楚后再考虑。"
    if level == "warning":
        return "可以继续问，但不要急着付款。这张配置单有一些信息需要商家补全。"
    return "目前没有发现明显硬伤，但购买前仍要确认具体品牌、型号和售后。"


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
        return f"{summary} 我主要担心：{problem_titles}。{question_text}"
    return f"{summary} {question_text}"


def _int_spec(component: DetectedReviewComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0


def _string_spec(component: DetectedReviewComponent, key: str) -> str:
    value = component.specs.get(key)
    return value if isinstance(value, str) else ""


def _is_outdated_clearance_component(component: DetectedReviewComponent) -> bool:
    normalized_name = _normalize(component.name + component.component_id)
    outdated_markers = ["e5", "xeon", "gt730", "gt710", "gtx750ti", "ddr3"]
    return any(marker in normalized_name for marker in outdated_markers)


def _looks_sold_as_performance_build(normalized_text: str) -> bool:
    performance_terms = ["高性能", "游戏主机", "电竞", "游戏显卡", "高端独显"]
    return any(_normalize(term) in normalized_text for term in performance_terms)


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
