from itertools import product
from typing import Dict, Iterable, List, Literal, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator

from app.builds.models import BuildTemplate
from app.catalog.models import ComponentPrice, HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility
from app.compat.engine import CompatibilityResult


BuildStatus = Literal["ready", "needs_ai_generation"]
BuildSource = Literal["template", "rules_fallback", "ai_provider", "ai_pending"]
FALLBACK_REQUIRED_ROLES = ["cpu", "motherboard", "ram", "psu"]
FALLBACK_OPTIONAL_ROLES = ["gpu", "storage"]
FALLBACK_MAX_CANDIDATES_PER_ROLE = 4
FALLBACK_MAX_COMBINATIONS_TO_EVALUATE = 5000
CPU_HEAVY_GAMES = frozenset({"瓦罗兰特", "CS2", "PUBG"})
BALANCED_GAMES = frozenset(
    {"什么都玩", "云顶之弈", "LOL", "COD", "城市天际线", "我的世界"}
)
GPU_HEAVY_GAMES = frozenset(
    {
        "三角洲行动",
        "赛博朋克2077",
        "荒野大镖客2",
        "GTA5",
        "黑神话悟空",
        "地平线6",
        "艾尔登法环",
    }
)
KNOWN_GAMES = CPU_HEAVY_GAMES | BALANCED_GAMES | GPU_HEAVY_GAMES


def classify_game_direction(
    games: List[str],
) -> Literal["fps", "aaa", "balanced"]:
    selected = set(games)
    if not selected or "什么都玩" in selected or not selected.issubset(KNOWN_GAMES):
        return "balanced"
    if selected.issubset(CPU_HEAVY_GAMES):
        return "fps"
    if selected.issubset(GPU_HEAVY_GAMES):
        return "aaa"
    return "balanced"


class BuildRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    budget: int = Field(ge=0, le=300_000)
    use_case: str = Field(
        min_length=1,
        max_length=64,
        validation_alias=AliasChoices("useCase", "use_case"),
    )
    preferences: List[str] = Field(default_factory=list, max_length=20)
    game_categories: List[str] = Field(
        default_factory=list,
        max_length=20,
        validation_alias=AliasChoices("gameCategories", "game_categories"),
    )
    office_apps: List[str] = Field(
        default_factory=list,
        max_length=20,
        validation_alias=AliasChoices("officeApps", "office_apps"),
    )
    purchase_preference: Optional[str] = Field(
        default=None,
        max_length=64,
        validation_alias=AliasChoices("purchasePreference", "purchase_preference"),
    )
    chassis_color: Optional[str] = Field(
        default=None,
        max_length=64,
        validation_alias=AliasChoices(
            "chassisColor",
            "chassisColorPreference",
            "chassis_color",
            "chassis_color_preference",
        ),
    )
    cpu_preference: Optional[str] = Field(
        default=None,
        max_length=64,
        validation_alias=AliasChoices("cpuPreference", "cpu_preference"),
    )
    gpu_preference: Optional[str] = Field(
        default=None,
        max_length=64,
        validation_alias=AliasChoices("gpuPreference", "gpu_preference"),
    )
    specified_cpu: Optional[str] = Field(
        default=None,
        max_length=128,
        validation_alias=AliasChoices("specifiedCPU", "specified_cpu"),
    )
    specified_gpu: Optional[str] = Field(
        default=None,
        max_length=128,
        validation_alias=AliasChoices("specifiedGPU", "specified_gpu"),
    )
    notes: Optional[str] = Field(default=None, max_length=1000)

    @field_validator("use_case")
    @classmethod
    def use_case_must_not_be_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Use case must not be blank")
        return normalized

    @field_validator("preferences", "game_categories", "office_apps")
    @classmethod
    def token_lists_must_be_bounded_and_unique(cls, value: List[str]) -> List[str]:
        normalized = []
        seen = set()
        for preference in value:
            item = preference.strip()
            if not item:
                raise ValueError("Preference must not be blank")
            if len(item) > 64:
                raise ValueError("Preference is too long")
            key = item.lower()
            if key in seen:
                raise ValueError("Preferences must be unique")
            seen.add(key)
            normalized.append(item)
        return normalized

    @field_validator(
        "purchase_preference",
        "chassis_color",
        "cpu_preference",
        "gpu_preference",
        "specified_cpu",
        "specified_gpu",
        "notes",
    )
    @classmethod
    def optional_text_must_not_be_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @property
    def preference_tokens(self) -> List[str]:
        tokens = [
            *self.preferences,
            *self.game_categories,
            *self.office_apps,
            self.purchase_preference,
            self.chassis_color,
            self.cpu_preference,
            self.gpu_preference,
            self.specified_cpu,
            self.specified_gpu,
        ]
        normalized = []
        seen = set()
        for token in tokens:
            if not token:
                continue
            key = token.lower()
            if key in seen:
                continue
            seen.add(key)
            normalized.append(token)
        return normalized


class BuildTemplatePart(BaseModel):
    role: Literal["cpu", "motherboard", "gpu", "ram", "storage", "psu", "cooler", "case"]
    component_id: str
    name: str
    condition: Literal["new", "used"]
    reference_price: int = Field(gt=0)
    price_source: str
    price_date: str
    specs: Dict[str, object] = Field(default_factory=dict)


class BuildTemplateDetails(BaseModel):
    target_budget: int = Field(ge=0)
    direction: Literal["fps", "aaa", "balanced"]
    purchase_mode: Literal["new", "used", "mixed"]
    parts: List[BuildTemplatePart]
    advantages: List[str]
    disadvantages: List[str]
    risks: List[str]
    suitable_user: str
    price_date: str


class BuildTemplateInput(BaseModel):
    id: str
    title: str
    budget_min: int
    budget_max: int
    use_cases: List[str]
    tags: List[str]
    components: Dict[str, str]
    estimated_total: Optional[int] = None
    explanation: str
    details: Optional[BuildTemplateDetails] = None


class BuildGenerationResponse(BaseModel):
    status: BuildStatus
    source: BuildSource
    template_id: Optional[str]
    title: str
    components: Dict[str, str]
    estimated_total: Optional[int]
    explanation: str
    details: Optional[BuildTemplateDetails] = None
    compatibility: Optional[CompatibilityResult]


class BuildOptionsResponse(BaseModel):
    direction: Literal["fps", "aaa", "balanced"]
    options: List[BuildGenerationResponse]
    unavailable_modes: List[Literal["new", "used", "mixed"]]


def match_build_template(
    request: BuildRequest,
    templates: List[BuildTemplate],
) -> Optional[BuildTemplate]:
    requested_direction = _requested_direction(request.preference_tokens)
    requested_purchase_mode = _requested_purchase_mode(request.preference_tokens)
    candidates = [
        template
        for template in templates
        if (template.status is None or template.status == "active")
        and template.budget_min <= request.budget <= template.budget_max
        and request.use_case in template.use_cases
        and _structured_template_matches(
            template,
            requested_direction,
            requested_purchase_mode,
        )
    ]
    if not candidates:
        return None

    preferences = set(request.preference_tokens)
    return min(
        candidates,
        key=lambda template: (
            -_structured_match_count(
                template,
                requested_direction,
                requested_purchase_mode,
            ),
            -len(preferences.intersection(set(template.tags))),
            -_default_direction_rank(template),
            -_default_purchase_rank(template),
            template.budget_max - template.budget_min,
            template.id,
        ),
    )


def _requested_direction(tokens: List[str]) -> Optional[str]:
    normalized = [token.strip().upper() for token in tokens]
    if any("FPS" in token for token in normalized):
        return "fps"
    if any("3A" in token for token in normalized):
        return "aaa"
    if any("均衡" in token for token in normalized):
        return "balanced"
    return None


def _requested_purchase_mode(tokens: List[str]) -> Optional[str]:
    normalized = [token.replace(" ", "") for token in tokens]
    if any(
        "混合" in token
        or "部分配件二手" in token
        or "新旧" in token
        or "半二手" in token
        for token in normalized
    ):
        return "mixed"
    if any("全新" in token for token in normalized):
        return "new"
    if any("二手" in token for token in normalized):
        return "used"
    return None


def _structured_template_matches(
    template: BuildTemplate,
    direction: Optional[str],
    purchase_mode: Optional[str],
) -> bool:
    template_direction = _template_detail(template, "direction")
    template_purchase_mode = _template_detail(template, "purchase_mode")
    if direction and template_direction and template_direction != direction:
        return False
    if purchase_mode and template_purchase_mode and template_purchase_mode != purchase_mode:
        return False
    return True


def _structured_match_count(
    template: BuildTemplate,
    direction: Optional[str],
    purchase_mode: Optional[str],
) -> int:
    return int(bool(direction) and _template_detail(template, "direction") == direction) + int(
        bool(purchase_mode)
        and _template_detail(template, "purchase_mode") == purchase_mode
    )


def _default_direction_rank(template: BuildTemplate) -> int:
    return {"balanced": 3, "fps": 2, "aaa": 1}.get(
        _template_detail(template, "direction"),
        0,
    )


def _default_purchase_rank(template: BuildTemplate) -> int:
    return {"new": 3, "mixed": 2, "used": 1}.get(
        _template_detail(template, "purchase_mode"),
        0,
    )


def _template_detail(template: BuildTemplate, key: str) -> Optional[str]:
    details = template.details or {}
    if isinstance(details, dict):
        value = details.get(key)
    else:
        value = getattr(details, key, None)
    return value if isinstance(value, str) else None


def template_response(
    template: BuildTemplate,
    compatibility: CompatibilityResult,
) -> BuildGenerationResponse:
    return BuildGenerationResponse(
        status="ready",
        source="template",
        template_id=template.id,
        title=template.title,
        components=dict(template.components),
        estimated_total=template.estimated_total,
        explanation=template.explanation,
        details=BuildTemplateDetails.model_validate(template.details) if template.details else None,
        compatibility=compatibility,
    )


def ai_provider_response(
    request: BuildRequest,
    components: Dict[str, str],
    explanation: str,
    estimated_total: int,
    compatibility: CompatibilityResult,
) -> BuildGenerationResponse:
    return BuildGenerationResponse(
        status="ready",
        source="ai_provider",
        template_id=None,
        title=f"{request.budget} 元{request.use_case}AI 受控配置",
        components=components,
        estimated_total=estimated_total,
        explanation=explanation,
        compatibility=compatibility,
    )


def rules_fallback_after_ai_failure(response: BuildGenerationResponse) -> BuildGenerationResponse:
    response.explanation = "外部 AI 暂不可用，已退回后端规则兜底配置。" + response.explanation
    return response


def rules_fallback_response(
    request: BuildRequest,
    components: List[HardwareComponent],
    prices: List[ComponentPrice],
) -> Optional[BuildGenerationResponse]:
    price_by_component_id = {price.component_id: price for price in prices}
    components_by_id = {component.id: component for component in components}
    candidates_by_role = fallback_candidates_by_role(components, price_by_component_id)
    required_roles = _required_fallback_roles(request, candidates_by_role)

    if any(not candidates_by_role.get(role) for role in required_roles):
        return None

    roles = required_roles + [
        role
        for role in FALLBACK_OPTIONAL_ROLES
        if role not in required_roles and candidates_by_role.get(role)
    ]
    best_selection: Optional[Dict[str, str]] = None
    best_total: Optional[int] = None
    best_compatibility: Optional[CompatibilityResult] = None
    best_score: Optional[float] = None
    evaluated_combinations = 0

    candidate_groups = [candidates_by_role[role] for role in roles]
    for selected_components in product(*candidate_groups):
        selection = {
            role: component.id
            for role, component in zip(roles, selected_components)
        }
        total = sum(price_by_component_id[component_id].reference_price for component_id in selection.values())
        if total > request.budget:
            continue

        # 防御性上限：避免候选数据膨胀或恶意请求导致单次兜底计算占满 CPU。
        if evaluated_combinations >= FALLBACK_MAX_COMBINATIONS_TO_EVALUATE:
            break
        evaluated_combinations += 1

        compatibility = evaluate_compatibility(
            BuildSelection(components=selection),
            components_by_id,
        )
        if not compatibility.compatible:
            continue

        score = _fallback_score(
            request=request,
            selected_components=list(selected_components),
            total=total,
            compatibility=compatibility,
        )
        if best_score is None or score > best_score:
            best_score = score
            best_selection = selection
            best_total = total
            best_compatibility = compatibility

    if best_selection is None or best_total is None or best_compatibility is None:
        return None

    return BuildGenerationResponse(
        status="ready",
        source="rules_fallback",
        template_id=None,
        title=f"{request.budget} 元{request.use_case}规则兜底配置",
        components=best_selection,
        estimated_total=best_total,
        explanation=(
            "未命中人工档位模板时，后端先从维护中的硬件库和人工复核价格库里选择真实型号，"
            "再经过兼容性规则复校；配置 DeepSeek API Key 和审核模板后，可继续升级为受约束 AI 挑选。"
        ),
        compatibility=best_compatibility,
    )


def ai_pending_response(ai_provider_configured: bool = False) -> BuildGenerationResponse:
    explanation = (
        "没有命中审核配置模板，也没有足够的受控候选硬件和人工价格数据；"
        "后端不会让 AI 自由编造硬件型号。请先发布审核配置模板或推荐候选池。"
        if ai_provider_configured
        else "没有命中现有配置模板，等待配置 AI API Key 后生成。"
    )
    return BuildGenerationResponse(
        status="needs_ai_generation",
        source="ai_pending",
        template_id=None,
        title="需要 AI 生成新配置",
        components={},
        estimated_total=None,
        explanation=explanation,
        compatibility=None,
    )


def fallback_candidates_by_role(
    components: Iterable[HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> Dict[str, List[HardwareComponent]]:
    candidates_by_role: Dict[str, List[HardwareComponent]] = {}
    for component in components:
        if not component.is_recommended or component.status != "active":
            continue
        if component.id not in price_by_component_id:
            continue
        candidates_by_role.setdefault(component.category, []).append(component)

    for role, candidates in candidates_by_role.items():
        candidates.sort(
            key=lambda component: (
                _int_spec(component, "perf_index"),
                price_by_component_id[component.id].reference_price,
                component.id,
            ),
            reverse=True,
        )
        candidates_by_role[role] = candidates[:FALLBACK_MAX_CANDIDATES_PER_ROLE]
    return candidates_by_role


def _required_fallback_roles(
    request: BuildRequest,
    candidates_by_role: Dict[str, List[HardwareComponent]],
) -> List[str]:
    roles = list(FALLBACK_REQUIRED_ROLES)
    normalized_use_case = request.use_case.lower()
    if (
        "game" in normalized_use_case
        or "gaming" in normalized_use_case
        or "游戏" in request.use_case
        or candidates_by_role.get("gpu")
    ):
        roles.append("gpu")
    return roles


def _fallback_score(
    request: BuildRequest,
    selected_components: List[HardwareComponent],
    total: int,
    compatibility: CompatibilityResult,
) -> float:
    usage_score = total / request.budget * 100
    perf_score = sum(_weighted_perf(component, request.use_case) for component in selected_components)
    preference_score = sum(
        _preference_matches(component, request.preference_tokens) * 5
        for component in selected_components
    )
    warning_penalty = compatibility.finding_counts["warning"] * 15
    return usage_score + perf_score + preference_score - warning_penalty


def _weighted_perf(component: HardwareComponent, use_case: str) -> float:
    perf = _int_spec(component, "perf_index")
    if component.category == "gpu" and ("game" in use_case.lower() or "游戏" in use_case):
        return perf * 1.5
    if component.category == "cpu":
        return perf
    return perf * 0.4


def _preference_matches(component: HardwareComponent, preferences: List[str]) -> int:
    searchable = " ".join(
        [
            component.id,
            component.name,
            component.brand,
            component.detail_raw,
            " ".join(str(value) for value in component.specs.values()),
        ]
    ).lower()
    return sum(1 for preference in preferences if preference.lower() in searchable)


def _int_spec(component: HardwareComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0
