from itertools import product
from typing import Dict, Iterable, List, Literal, Optional

from pydantic import (
    AliasChoices,
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.builds.models import BuildTemplate
from app.catalog.models import ComponentPrice, GPUWhitelistPrice, HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility
from app.compat.engine import CompatibilityResult
from app.perf.time_spy import GPU_TIME_SPY_SCORES


BuildStatus = Literal["ready", "needs_ai_generation"]
BuildSource = Literal["template", "rules_fallback", "ai_provider", "ai_pending"]
FALLBACK_REQUIRED_ROLES = ["cpu", "motherboard", "ram", "psu"]
FALLBACK_OPTIONAL_ROLES = ["gpu", "storage"]
FALLBACK_MAX_CANDIDATES_PER_ROLE = 4
FALLBACK_MAX_COMBINATIONS_TO_EVALUATE = 5000
USED_40_SERIES_PRICE_PREMIUM = 300
BLOCKED_USED_GPU_ALTERNATIVES = frozenset({"rtx-4070-ti"})
CPU_HEAVY_GAMES = frozenset({"瓦罗兰特", "CS2", "PUBG", "永劫无间"})
BALANCED_GAMES = frozenset(
    {
        "什么都玩",
        "云顶之弈",
        "LOL",
        "COD",
        "城市天际线",
        "我的世界",
        "暗区突围",
        "NBA2K",
        "穿越火线",
    }
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
GENERAL_OFFICE_APPS = frozenset({"Office", "WPS", "Photoshop", "AutoCAD"})
MEDIA_OFFICE_APPS = frozenset({"Premiere", "DaVinci Resolve", "剪映"})
CUDA_OFFICE_APPS = frozenset(
    {"Blender", "After Effects", "MATLAB", "本地 AI", "本地AI"}
)


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


def classify_office_workload(
    apps: List[str],
) -> Literal["general", "media", "cuda"]:
    selected = set(apps)
    if selected & CUDA_OFFICE_APPS:
        return "cuda"
    if selected & MEDIA_OFFICE_APPS:
        return "media"
    if selected and not selected.issubset(GENERAL_OFFICE_APPS):
        return "cuda"
    return "general"


class AestheticBuildPart(BaseModel):
    component_id: str = Field(min_length=1, max_length=256)
    role: Literal["case", "cooler", "extra"]
    category: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=160)
    condition: Literal["new", "used"] = "new"
    reference_price: int = Field(gt=0, le=100_000)
    supports_hot_cpu: bool = False


class AestheticBuildSelection(BaseModel):
    style_id: str = Field(min_length=1, max_length=128)
    style_name: str = Field(min_length=1, max_length=128)
    color: Literal["black", "white"]
    price_date: str = Field(min_length=10, max_length=10)
    parts: List[AestheticBuildPart] = Field(min_length=1, max_length=20)

    @model_validator(mode="after")
    def require_complete_unique_style_parts(self) -> "AestheticBuildSelection":
        roles = [part.role for part in self.parts]
        if roles.count("case") != 1:
            raise ValueError("风格方案必须且只能锁定一个机箱")
        if roles.count("cooler") > 1:
            raise ValueError("风格方案最多锁定一个 CPU 散热器")
        component_ids = [part.component_id for part in self.parts]
        if len(component_ids) != len(set(component_ids)):
            raise ValueError("风格方案不能包含重复配件")
        return self

    @property
    def reference_total(self) -> int:
        return sum(part.reference_price for part in self.parts)


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
    direction: Optional[Literal["fps", "aaa", "balanced"]] = None
    ray_tracing: Optional[bool] = Field(
        default=None,
        validation_alias=AliasChoices("rayTracing", "ray_tracing"),
    )
    needs_wireless_network: bool = Field(
        default=False,
        validation_alias=AliasChoices(
            "needsWirelessNetwork",
            "needs_wireless_network",
        ),
    )
    memory_size: Optional[Literal["16GB", "32GB"]] = Field(
        default=None,
        validation_alias=AliasChoices("memorySize", "memory_size"),
    )
    storage_size: Optional[Literal["512GB", "1TB", "2TB"]] = Field(
        default=None,
        validation_alias=AliasChoices("storageSize", "storage_size"),
    )
    allows_flexible_budget: bool = Field(
        default=False,
        validation_alias=AliasChoices(
            "allowsFlexibleBudget",
            "allows_flexible_budget",
        ),
    )
    no_gpu_build: bool = Field(
        default=False,
        validation_alias=AliasChoices("noGPUBuild", "no_gpu_build"),
    )
    owned_gpu_model: Optional[str] = Field(
        default=None,
        max_length=128,
        validation_alias=AliasChoices("ownedGPUModel", "owned_gpu_model"),
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
    aesthetic_style: Optional[AestheticBuildSelection] = Field(
        default=None,
        validation_alias=AliasChoices("aestheticStyle", "aesthetic_style"),
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
        "owned_gpu_model",
        "notes",
    )
    @classmethod
    def optional_text_must_not_be_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @model_validator(mode="after")
    def owned_gpu_is_required_for_no_gpu_build(self) -> "BuildRequest":
        if self.no_gpu_build and not self.owned_gpu_model:
            raise ValueError("无显卡方案必须提供自备显卡型号")
        return self

    @property
    def requires_customization(self) -> bool:
        return any(
            (
                self.needs_wireless_network,
                self.use_case != "办公" and self.memory_size is not None,
                self.use_case != "办公" and self.storage_size is not None,
                self.no_gpu_build,
                bool(self.office_apps) and self.use_case != "办公",
                self.aesthetic_style is not None,
                bool(self.notes),
            )
        )

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
    condition: Literal["new", "used", "owned"]
    reference_price: int = Field(ge=0)
    price_source: str
    price_date: str
    specs: Dict[str, object] = Field(default_factory=dict)


class BuildTemplateExtra(BaseModel):
    id: str
    name: str
    condition: Literal["new", "used"]
    reference_price: int = Field(gt=0)
    category: Optional[str] = Field(
        default=None,
        exclude_if=lambda value: value is None,
    )


class UsedGPUAlternative(BaseModel):
    component_id: str
    name: str
    reference_price: int = Field(gt=0)
    price_difference: int
    performance_comparison: Literal["higher", "similar"]
    gaming_performance_gain_percent: int = Field(default=0, ge=0)


class BuildTemplateDetails(BaseModel):
    target_budget: int = Field(ge=0)
    direction: Literal["fps", "aaa", "balanced"]
    purchase_mode: Literal["new", "used", "mixed"]
    gpu_vendor: Literal["nvidia", "amd", "intel"]
    parts: List[BuildTemplatePart]
    extras: List[BuildTemplateExtra] = Field(
        default_factory=list,
        exclude_if=lambda value: not value,
    )
    used_gpu_alternative: Optional[UsedGPUAlternative] = Field(
        default=None,
        exclude_if=lambda value: value is None,
    )
    aesthetic_style_id: Optional[str] = Field(
        default=None,
        exclude_if=lambda value: value is None,
    )
    aesthetic_style_name: Optional[str] = Field(
        default=None,
        exclude_if=lambda value: value is None,
    )
    aesthetic_color: Optional[Literal["black", "white"]] = Field(
        default=None,
        exclude_if=lambda value: value is None,
    )
    performance_total: Optional[int] = Field(
        default=None,
        ge=0,
        exclude_if=lambda value: value is None,
    )
    appearance_total: Optional[int] = Field(
        default=None,
        ge=0,
        exclude_if=lambda value: value is None,
    )
    suitable_user: str
    price_date: str

    @model_validator(mode="before")
    @classmethod
    def infer_legacy_gpu_vendor(cls, value):
        if not isinstance(value, dict) or value.get("gpu_vendor"):
            return value
        gpu = next(
            (
                part
                for part in value.get("parts", [])
                if isinstance(part, dict) and part.get("role") == "gpu"
            ),
            None,
        )
        if gpu is None:
            return value
        vendor = gpu.get("specs", {}).get("vendor")
        component_id = gpu.get("component_id", "")
        if isinstance(vendor, str):
            vendor = vendor.lower()
        if vendor not in {"nvidia", "amd", "intel"}:
            vendor = (
                "nvidia"
                if component_id.startswith("rtx-")
                else "intel"
                if component_id.startswith("arc-")
                else "amd"
            )
        return {**value, "gpu_vendor": vendor}


def recommend_used_40_series_gpu(
    details: BuildTemplateDetails,
    gpu_prices: Iterable[GPUWhitelistPrice],
) -> Optional[UsedGPUAlternative]:
    if details.purchase_mode != "new" or details.gpu_vendor != "nvidia":
        return None

    current_gpu = next(
        (part for part in details.parts if part.role == "gpu"),
        None,
    )
    if current_gpu is None or current_gpu.condition != "new":
        return None

    current_score = GPU_TIME_SPY_SCORES.get(current_gpu.component_id)
    if current_score is None:
        return None

    candidates = []
    for price in gpu_prices:
        candidate_id = price.component_id
        candidate_price = price.used_price
        candidate_score = GPU_TIME_SPY_SCORES.get(candidate_id)
        if (
            not candidate_id.startswith("rtx-4")
            or candidate_id == current_gpu.component_id
            or candidate_id in BLOCKED_USED_GPU_ALTERNATIVES
            or candidate_price is None
            or candidate_score is None
            or candidate_price > current_gpu.reference_price + USED_40_SERIES_PRICE_PREMIUM
            or candidate_score < current_score
        ):
            continue
        candidates.append((candidate_score, -candidate_price, price))

    if not candidates:
        return None

    candidate_score, _, candidate = max(candidates, key=lambda item: item[:2])
    candidate_price = candidate.used_price
    if candidate_price is None:
        return None
    return UsedGPUAlternative(
        component_id=candidate.component_id,
        name=candidate.name,
        reference_price=candidate_price,
        price_difference=candidate_price - current_gpu.reference_price,
        performance_comparison=(
            "higher" if candidate_score > current_score else "similar"
        ),
        gaming_performance_gain_percent=round(
            (candidate_score - current_score) * 100 / current_score
        ),
    )


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


class BuildOptionResponse(BaseModel):
    status: Literal["ready"]
    source: Literal["template", "ai_provider", "selection_cache"]
    template_id: str
    selection_id: Optional[str] = None
    title: str
    components: Dict[str, str]
    estimated_total: Optional[int]
    explanation: str
    details: BuildTemplateDetails

    @model_validator(mode="after")
    def require_complete_matching_parts(self) -> "BuildOptionResponse":
        parts_by_role = {part.role: part.component_id for part in self.details.parts}
        if len(self.details.parts) != 8 or len(parts_by_role) != 8:
            raise ValueError("details must contain eight unique parts")
        if self.components != parts_by_role:
            raise ValueError("components must match detailed parts")
        return self


def resolve_aesthetic_style(
    selection: AestheticBuildSelection,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> AestheticBuildSelection:
    expected_categories = {
        "case": "case",
        "cooler": "cooler",
        "extra": "aesthetic_extra",
    }
    resolved_parts = []
    style_names = set()
    price_dates = []
    for part in selection.parts:
        component = components_by_id.get(part.component_id)
        price = price_by_component_id.get(part.component_id)
        if (
            component is None
            or price is None
            or not component.id.startswith("aesthetic-")
            or component.status != "active"
            or component.category != expected_categories[part.role]
        ):
            raise ValueError(f"风格配件未录入正式硬件目录：{part.name}")
        specs = component.specs
        styles = specs.get("aesthetic_styles")
        if not isinstance(styles, dict) or selection.style_id not in styles:
            raise ValueError(f"风格配件不属于当前方案：{component.name}")
        if specs.get("condition") != part.condition:
            raise ValueError(f"风格配件成色与正式目录不一致：{component.name}")
        if specs.get("color") != selection.color:
            raise ValueError(f"风格配件颜色与当前方案不一致：{component.name}")
        style_names.add(str(styles[selection.style_id]))
        price_dates.append(price.approved_at.date().isoformat())
        resolved_parts.append(
            AestheticBuildPart(
                component_id=component.id,
                role=part.role,
                category=str(specs.get("display_category") or part.category),
                name=component.name,
                condition=part.condition,
                reference_price=price.reference_price,
                supports_hot_cpu=bool(specs.get("supports_hot_cpu", False)),
            )
        )
    if len(style_names) != 1:
        raise ValueError("风格配件的方案名称不一致")
    return selection.model_copy(
        update={
            "style_name": style_names.pop(),
            "price_date": max(price_dates),
            "parts": resolved_parts,
        }
    )


def apply_aesthetic_style(
    option: BuildOptionResponse,
    selection: AestheticBuildSelection,
) -> BuildOptionResponse:
    details = option.details.model_copy(deep=True)
    parts = {part.role: part for part in details.parts}
    locked_parts = {part.role: part for part in selection.parts if part.role != "extra"}
    style_cooler = locked_parts.get("cooler")
    cpu = parts["cpu"]
    hot_cpu = (
        cpu.component_id in {"r7-7800x3d", "r7-9800x3d", "r7-9850x3d"}
        or isinstance(cpu.specs.get("tdp"), int)
        and cpu.specs["tdp"] >= 120
    )
    if style_cooler is not None and hot_cpu and not style_cooler.supports_hot_cpu:
        raise ValueError("所选风格散热器无法安全支持当前高热 CPU")

    replaced_price = 0
    for role, style_part in locked_parts.items():
        replaced_price += parts[role].reference_price
        cooler_specs = (
            {
                "cooling_type": "style",
                "heatpipes": 6,
                "towers": 2 if style_part.supports_hot_cpu else 1,
            }
            if role == "cooler"
            else {}
        )
        parts[role] = BuildTemplatePart(
            role=role,
            component_id=style_part.component_id,
            name=style_part.name,
            condition=style_part.condition,
            reference_price=style_part.reference_price,
            price_source="人工核实风格方案",
            price_date=selection.price_date,
            specs=cooler_specs,
        )

    style_extras = [
        BuildTemplateExtra(
            id=part.component_id,
            name=part.name,
            condition=part.condition,
            reference_price=part.reference_price,
            category=part.category,
        )
        for part in selection.parts
        if part.role == "extra"
    ]
    performance_total = option.estimated_total or sum(
        part.reference_price for part in option.details.parts
    ) + sum(extra.reference_price for extra in option.details.extras)
    details.parts = [parts[part.role] for part in details.parts]
    details.extras = [*details.extras, *style_extras]
    details.aesthetic_style_id = selection.style_id
    details.aesthetic_style_name = selection.style_name
    details.aesthetic_color = selection.color
    details.performance_total = performance_total
    details.appearance_total = selection.reference_total
    details.price_date = max(details.price_date, selection.price_date)
    components = {role: part.component_id for role, part in parts.items()}

    return option.model_copy(
        update={
            "title": f"{selection.style_name} · {option.title}",
            "components": components,
            "estimated_total": performance_total - replaced_price + selection.reference_total,
            "explanation": (
                f"{option.explanation}；已锁定{selection.style_name}"
                f"（{'黑色' if selection.color == 'black' else '白色'}）外观配件。"
            )[:500],
            "details": details,
        }
    )


class BuildOptionsResponse(BaseModel):
    direction: Literal["fps", "aaa", "balanced"]
    options: List[BuildOptionResponse]
    unavailable_modes: List[Literal["new", "used", "mixed"]]
    unavailable_mode_reasons: Dict[Literal["new", "used", "mixed"], str] = Field(
        default_factory=dict
    )


class BuildSelectionConfirmationResponse(BaseModel):
    selection_id: str
    selected_count: int = Field(ge=1)


def rank_build_templates(
    request: BuildRequest,
    templates: List[BuildTemplate],
) -> List[BuildTemplate]:
    requested_direction = _requested_direction(request.preference_tokens)
    requested_purchase_mode = _requested_purchase_mode(request.preference_tokens)
    requested_gpu_vendor = _requested_gpu_vendor(request.preference_tokens)
    requested_office_workload = (
        classify_office_workload(request.office_apps)
        if request.use_case == "办公"
        else None
    )
    candidates = [
        template
        for template in templates
        if (template.status is None or template.status == "active")
        and template.budget_min <= request.budget <= template.budget_max
        and request.use_case in template.use_cases
        and _office_workload_matches(template, requested_office_workload)
        and _structured_template_matches(
            template,
            requested_direction,
            requested_purchase_mode,
            requested_gpu_vendor,
        )
    ]
    preferences = set(request.preference_tokens)
    return sorted(
        candidates,
        key=lambda template: (
            -_structured_match_count(
                template,
                requested_direction,
                requested_purchase_mode,
                requested_gpu_vendor,
            ),
            -len(preferences.intersection(set(template.tags))),
            template.budget_max - template.budget_min,
            -_default_direction_rank(template),
            -_default_purchase_rank(template),
            -_default_gpu_vendor_rank(template),
            template.id,
        ),
    )


def match_build_template(
    request: BuildRequest,
    templates: List[BuildTemplate],
) -> Optional[BuildTemplate]:
    candidates = rank_build_templates(request, templates)
    return candidates[0] if candidates else None


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


def _requested_gpu_vendor(tokens: List[str]) -> Optional[str]:
    normalized = [token.replace(" ", "").lower() for token in tokens]
    if any(token in {"nvidia", "n卡", "英伟达"} for token in normalized):
        return "nvidia"
    if any(token in {"amd", "a卡"} for token in normalized):
        return "amd"
    if any(token in {"intel", "arc", "英特尔"} for token in normalized):
        return "intel"
    return None


def _office_workload_matches(
    template: BuildTemplate,
    workload: Optional[str],
) -> bool:
    if workload is None:
        return True
    office_tags = {tag for tag in template.tags if tag.startswith("office-")}
    return not office_tags or f"office-{workload}" in office_tags


def _structured_template_matches(
    template: BuildTemplate,
    direction: Optional[str],
    purchase_mode: Optional[str],
    gpu_vendor: Optional[str],
) -> bool:
    template_direction = _template_detail(template, "direction")
    template_purchase_mode = _template_detail(template, "purchase_mode")
    if direction and template_direction and template_direction != direction:
        return False
    if purchase_mode and template_purchase_mode and template_purchase_mode != purchase_mode:
        return False
    template_gpu_vendor = _template_gpu_vendor(template)
    if gpu_vendor and template_gpu_vendor and template_gpu_vendor != gpu_vendor:
        return False
    return True


def _structured_match_count(
    template: BuildTemplate,
    direction: Optional[str],
    purchase_mode: Optional[str],
    gpu_vendor: Optional[str],
) -> int:
    return (
        int(bool(direction) and _template_detail(template, "direction") == direction)
        + int(
            bool(purchase_mode)
            and _template_detail(template, "purchase_mode") == purchase_mode
        )
        + int(bool(gpu_vendor) and _template_gpu_vendor(template) == gpu_vendor)
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


def _default_gpu_vendor_rank(template: BuildTemplate) -> int:
    return {"nvidia": 2, "amd": 1}.get(_template_gpu_vendor(template), 0)


def _template_detail(template: BuildTemplate, key: str) -> Optional[str]:
    details = template.details or {}
    if isinstance(details, dict):
        value = details.get(key)
    else:
        value = getattr(details, key, None)
    return value if isinstance(value, str) else None


def _template_gpu_vendor(template: BuildTemplate) -> Optional[str]:
    structured = _template_detail(template, "gpu_vendor")
    if structured in {"nvidia", "amd", "intel"}:
        return structured
    gpu_id = (template.components or {}).get("gpu", "")
    if not gpu_id:
        return None
    if gpu_id.startswith("rtx-"):
        return "nvidia"
    if gpu_id.startswith("arc-"):
        return "intel"
    return "amd"


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
    candidates_by_role = fallback_candidates_by_role(
        components,
        price_by_component_id,
        use_case=request.use_case,
    )
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
    *,
    use_case: str = "游戏",
) -> Dict[str, List[HardwareComponent]]:
    candidates_by_role: Dict[str, List[HardwareComponent]] = {}
    for component in components:
        if not component.is_recommended or component.status != "active":
            continue
        if component.id not in price_by_component_id:
            continue
        if (
            component.category == "gpu"
            and component.id.startswith("arc-")
            and use_case != "办公"
        ):
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
