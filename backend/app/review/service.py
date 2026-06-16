import re
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import list_component_prices, list_components


ReviewRiskLevel = Literal["pass", "warning", "error"]

ROLE_LABELS = {
    "cpu": "CPU",
    "gpu": "显卡",
    "motherboard": "主板",
    "ram": "内存",
    "storage": "硬盘",
    "psu": "电源",
}

REVIEW_ROLES = ["cpu", "gpu", "motherboard", "ram", "storage", "psu"]


class ConfigReviewRequest(BaseModel):
    text: str = Field(min_length=12, max_length=5000)


class DetectedReviewComponent(BaseModel):
    role: str
    component_id: str
    name: str
    brand: str
    confidence: Literal["exact", "partial"]


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
    prices = {price.component_id: price for price in list_component_prices(session)}
    detected = _detect_components(normalized_text, components)
    seller_price = _parse_seller_price(text)
    reference_total = _reference_total(detected, prices)
    findings = _build_findings(detected, prices, seller_price, reference_total)
    questions = _questions_for_seller(detected, findings)
    risk_level = _overall_level(findings)
    summary = _summary_for_level(risk_level)
    reply_text = _reply_text(summary, findings, questions)
    return ConfigReviewResponse(
        risk_level=risk_level,
        summary=summary,
        source_text=text,
        seller_price=seller_price,
        reference_total=reference_total,
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
    prices: Dict[str, ComponentPrice],
    seller_price: Optional[int],
    reference_total: Optional[int],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    findings.extend(_missing_core_findings(detected))
    findings.extend(_balance_findings(detected))
    findings.extend(_motherboard_findings(detected))
    findings.extend(_psu_findings(detected))
    findings.extend(_price_findings(detected, prices, seller_price, reference_total))
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


def _balance_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    gpu = detected.get("gpu")
    if cpu is None or gpu is None:
        return []
    cpu_tier = _cpu_tier(cpu.name)
    gpu_tier = _gpu_tier(gpu.name)
    if cpu_tier >= 7 and gpu_tier <= 4060:
        return [
            ReviewFinding(
                level="error",
                code="cpu_gpu_imbalance",
                title="CPU 偏高，显卡偏弱",
                detail=f"{cpu.name} 搭配 {gpu.name} 对游戏用户不均衡，预算更容易花在看不见的地方。",
                component_ids=[cpu.component_id, gpu.component_id],
            )
        ]
    return []


def _motherboard_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    cpu = detected.get("cpu")
    motherboard = detected.get("motherboard")
    if cpu is None or motherboard is None:
        return []
    board_name = motherboard.name.upper()
    if _cpu_tier(cpu.name) >= 7 and ("H610" in board_name or "A620" in board_name):
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


def _psu_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
) -> List[ReviewFinding]:
    psu = detected.get("psu")
    if psu is None:
        return []
    if psu.brand in {"未知", "Unknown", ""}:
        return [
            ReviewFinding(
                level="warning",
                code="psu_model_unclear",
                title="电源品牌型号不明确",
                detail="配置单只写了电源瓦数，没有可靠品牌、具体型号和认证信息，整机风险主要会集中在这里。",
                component_ids=[psu.component_id],
            )
        ]
    return []


def _price_findings(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    prices: Dict[str, ComponentPrice],
    seller_price: Optional[int],
    reference_total: Optional[int],
) -> List[ReviewFinding]:
    findings: List[ReviewFinding] = []
    missing_price_roles = [
        ROLE_LABELS[role]
        for role, component in detected.items()
        if component is not None and component.component_id not in prices
    ]
    if missing_price_roles:
        findings.append(
            ReviewFinding(
                level="warning",
                code="missing_reference_price",
                title="参考价不完整",
                detail="、".join(missing_price_roles) + " 暂时没有人工确认参考价，报价判断只能作为部分参考。",
            )
        )
    if seller_price is None:
        findings.append(
            ReviewFinding(
                level="warning",
                code="seller_price_missing",
                title="缺少整机报价",
                detail="配置单里没有识别到明确总价，暂时不能判断是否虚高。",
            )
        )
    elif reference_total is not None and seller_price > reference_total * 1.18:
        findings.append(
            ReviewFinding(
                level="error",
                code="seller_price_high",
                title="报价明显偏高",
                detail=f"已识别配件参考价合计约 {reference_total} 元，商家报价 {seller_price} 元，差距偏大。",
            )
        )
    return findings


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


def _overall_level(findings: List[ReviewFinding]) -> ReviewRiskLevel:
    if any(finding.level == "error" for finding in findings):
        return "error"
    if any(finding.level == "warning" for finding in findings):
        return "warning"
    return "pass"


def _summary_for_level(level: ReviewRiskLevel) -> str:
    if level == "error":
        return "不建议直接买。这张配置单存在比较明显的风险点，需要让商家改清楚后再考虑。"
    if level == "warning":
        return "可以继续问，但不要急着付款。这张配置单有一些信息需要商家补全。"
    return "目前没有发现明显硬伤，但付款前仍要确认具体品牌、型号和售后。"


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


def _reference_total(
    detected: Dict[str, Optional[DetectedReviewComponent]],
    prices: Dict[str, ComponentPrice],
) -> Optional[int]:
    total = 0
    matched = 0
    for component in detected.values():
        if component is None:
            continue
        price = prices.get(component.component_id)
        if price is None:
            continue
        total += price.reference_price
        matched += 1
    return total if matched else None


def _parse_seller_price(text: str) -> Optional[int]:
    labeled_match = re.search(r"(?:报价|价格|售价|总价|整机)[^\d]{0,8}(\d{3,6})", text)
    if labeled_match:
        return int(labeled_match.group(1))
    numbers = [int(value) for value in re.findall(r"\d{4,6}", text)]
    return numbers[-1] if numbers else None


def _cpu_tier(name: str) -> int:
    lowered = name.lower()
    match = re.search(r"(?:i|r)([3579])", lowered)
    if match:
        return int(match.group(1))
    return 0


def _gpu_tier(name: str) -> int:
    match = re.search(r"(\d{4})", name)
    return int(match.group(1)) if match else 0


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
