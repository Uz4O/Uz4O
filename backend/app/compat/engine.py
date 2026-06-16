from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field

from app.catalog.models import HardwareComponent


FindingLevel = Literal["pass", "warning", "error"]
COMPATIBILITY_RULE_VERSION = "2026-06-16"
REQUIRED_ROLES = {
    "cpu": "CPU",
    "motherboard": "主板",
    "ram": "内存",
    "psu": "电源",
}


class CompatibilityRule(BaseModel):
    code: str
    title: str
    description: str
    level_when_failed: FindingLevel


COMPATIBILITY_RULES = [
    CompatibilityRule(
        code="unknown_component",
        title="硬件库型号校验",
        description="所有传入型号必须能在维护中的硬件库里找到。",
        level_when_failed="error",
    ),
    CompatibilityRule(
        code="missing_required",
        title="核心配件完整性",
        description="CPU、主板、内存和电源是完整兼容性判断的必需项。",
        level_when_failed="error",
    ),
    CompatibilityRule(
        code="cpu_motherboard_socket",
        title="CPU 和主板插槽",
        description="CPU socket 必须和主板 socket 一致。",
        level_when_failed="error",
    ),
    CompatibilityRule(
        code="motherboard_ram_type",
        title="主板和内存代际",
        description="主板内存代际必须和内存类型一致。",
        level_when_failed="error",
    ),
    CompatibilityRule(
        code="psu_headroom",
        title="电源余量",
        description="电源瓦数需要覆盖 CPU/GPU 等配件的估算功耗并留有余量。",
        level_when_failed="warning",
    ),
    CompatibilityRule(
        code="cpu_gpu_balance",
        title="CPU/GPU 搭配均衡",
        description="用 perf_index 检查高 U 低显或低 U 高显。",
        level_when_failed="warning",
    ),
    CompatibilityRule(
        code="cpu_motherboard_tier",
        title="CPU 和主板档次",
        description="高端 CPU 搭配入门主板时给出稳定性和扩展性提醒。",
        level_when_failed="warning",
    ),
]


class BuildSelection(BaseModel):
    components: Dict[str, str] = Field(max_length=24)

    def component_id(self, role: str) -> Optional[str]:
        if role == "psu":
            return self.components.get("psu") or self.components.get("power_supply")
        return self.components.get(role)

    def selected_ids(self) -> List[str]:
        return [component_id for component_id in self.components.values() if component_id]


class CompatibilityFinding(BaseModel):
    level: FindingLevel
    code: str
    title: str
    detail: str
    component_ids: List[str]


class CompatibilityResult(BaseModel):
    compatible: bool
    summary: str
    findings: List[CompatibilityFinding]
    finding_counts: Dict[FindingLevel, int]
    checked_rule_codes: List[str]


class CompatibilityRulesResponse(BaseModel):
    version: str
    rules: List[CompatibilityRule]


def evaluate_compatibility(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> CompatibilityResult:
    findings: List[CompatibilityFinding] = []
    findings.extend(_unknown_component_findings(selection, components_by_id))
    findings.extend(_missing_required_findings(selection))
    findings.extend(_socket_findings(selection, components_by_id))
    findings.extend(_ram_type_findings(selection, components_by_id))
    findings.extend(_psu_headroom_findings(selection, components_by_id))
    findings.extend(_balance_findings(selection, components_by_id))
    findings.extend(_motherboard_tier_findings(selection, components_by_id))

    compatible = not any(finding.level == "error" for finding in findings)
    summary = (
        "这套配置没有发现硬性兼容问题。"
        if compatible
        else "这套配置有硬性兼容问题，需要先调整。"
    )
    return CompatibilityResult(
        compatible=compatible,
        summary=summary,
        findings=findings,
        finding_counts=_finding_counts(findings),
        checked_rule_codes=_checked_rule_codes(findings),
    )


def compatibility_rules_response() -> CompatibilityRulesResponse:
    return CompatibilityRulesResponse(version=COMPATIBILITY_RULE_VERSION, rules=COMPATIBILITY_RULES)


def _unknown_component_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    findings: List[CompatibilityFinding] = []
    for component_id in selection.selected_ids():
        if component_id not in components_by_id:
            findings.append(
                CompatibilityFinding(
                    level="error",
                    code="unknown_component",
                    title="硬件库找不到这个型号",
                    detail=f"没有在硬件库里找到 {component_id}，不能用它做兼容性判断。",
                    component_ids=[component_id],
                )
            )
    return findings


def _missing_required_findings(selection: BuildSelection) -> List[CompatibilityFinding]:
    findings: List[CompatibilityFinding] = []
    for role, label in REQUIRED_ROLES.items():
        if not selection.component_id(role):
            findings.append(
                CompatibilityFinding(
                    level="error",
                    code=f"missing_{role}",
                    title=f"缺少{label}",
                    detail=f"这套配置还没有选择{label}，不能完整判断兼容性。",
                    component_ids=[],
                )
            )
    return findings


def _socket_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    cpu = _component_for_role(selection, components_by_id, "cpu")
    motherboard = _component_for_role(selection, components_by_id, "motherboard")
    if cpu is None or motherboard is None:
        return []

    cpu_socket = _string_spec(cpu, "socket")
    motherboard_socket = _string_spec(motherboard, "socket")
    if not cpu_socket or not motherboard_socket:
        return []

    if cpu_socket != motherboard_socket:
        return [
            CompatibilityFinding(
                level="error",
                code="cpu_motherboard_socket",
                title="CPU 和主板插槽不匹配",
                detail=f"{cpu.name} 是 {cpu_socket}，{motherboard.name} 是 {motherboard_socket}，插槽不匹配。",
                component_ids=[cpu.id, motherboard.id],
            )
        ]

    return [
        CompatibilityFinding(
            level="pass",
            code="cpu_motherboard_socket",
            title="CPU 和主板插槽匹配",
            detail=f"{cpu.name} 可以安装在 {motherboard.name} 上。",
            component_ids=[cpu.id, motherboard.id],
        )
    ]


def _ram_type_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    motherboard = _component_for_role(selection, components_by_id, "motherboard")
    ram = _component_for_role(selection, components_by_id, "ram")
    if motherboard is None or ram is None:
        return []

    motherboard_mem_type = _string_spec(motherboard, "mem_type")
    ram_type = _string_spec(ram, "type")
    if not motherboard_mem_type or not ram_type:
        return []

    if motherboard_mem_type != ram_type:
        return [
            CompatibilityFinding(
                level="error",
                code="motherboard_ram_type",
                title="主板和内存代际不匹配",
                detail=f"{motherboard.name} 需要 {motherboard_mem_type} 内存，但你选的是 {ram_type}。",
                component_ids=[motherboard.id, ram.id],
            )
        ]

    return [
        CompatibilityFinding(
            level="pass",
            code="motherboard_ram_type",
            title="主板和内存代际匹配",
            detail=f"{motherboard.name} 和 {ram.name} 的内存代际匹配。",
            component_ids=[motherboard.id, ram.id],
        )
    ]


def _psu_headroom_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    psu = _component_for_role(selection, components_by_id, "psu")
    if psu is None:
        return []

    psu_watt = _int_spec(psu, "watt")
    total_tdp = sum(
        _int_spec(component, "tdp") or 0
        for component in components_by_id.values()
        if component.category != "psu"
    )
    if not psu_watt or total_tdp <= 0:
        return []

    if psu_watt < total_tdp:
        return [
            CompatibilityFinding(
                level="error",
                code="psu_headroom",
                title="电源瓦数不够",
                detail=f"预计功耗约 {total_tdp}W，{psu_watt}W 电源可能带不动这套配置。",
                component_ids=[psu.id],
            )
        ]
    if psu_watt < total_tdp * 1.3:
        return [
            CompatibilityFinding(
                level="warning",
                code="psu_headroom",
                title="电源余量偏紧",
                detail=f"预计功耗约 {total_tdp}W，{psu_watt}W 电源余量偏紧，建议换更高瓦数。",
                component_ids=[psu.id],
            )
        ]

    return [
        CompatibilityFinding(
            level="pass",
            code="psu_headroom",
            title="电源余量正常",
            detail=f"预计功耗约 {total_tdp}W，{psu_watt}W 电源有基础余量。",
            component_ids=[psu.id],
        )
    ]


def _balance_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    cpu = _component_for_role(selection, components_by_id, "cpu")
    gpu = _component_for_role(selection, components_by_id, "gpu")
    if cpu is None or gpu is None:
        return []

    cpu_perf = _int_spec(cpu, "perf_index")
    gpu_perf = _int_spec(gpu, "perf_index")
    if cpu_perf <= 0 or gpu_perf <= 0:
        return []

    if cpu_perf >= gpu_perf * 1.6:
        return [
            CompatibilityFinding(
                level="warning",
                code="cpu_gpu_balance",
                title="CPU 明显强于显卡",
                detail=f"CPU 明显强于显卡：{cpu.name} 的性能档位高于 {gpu.name}，游戏场景可能是高 U 低显。",
                component_ids=[cpu.id, gpu.id],
            )
        ]
    if gpu_perf >= cpu_perf * 1.8:
        return [
            CompatibilityFinding(
                level="warning",
                code="cpu_gpu_balance",
                title="显卡明显强于 CPU",
                detail=f"{gpu.name} 的性能档位明显高于 {cpu.name}，高帧率游戏可能被 CPU 拖住。",
                component_ids=[cpu.id, gpu.id],
            )
        ]
    return [
        CompatibilityFinding(
            level="pass",
            code="cpu_gpu_balance",
            title="CPU 和显卡搭配均衡",
            detail=f"{cpu.name} 和 {gpu.name} 的性能档位没有明显失衡。",
            component_ids=[cpu.id, gpu.id],
        )
    ]


def _motherboard_tier_findings(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
) -> List[CompatibilityFinding]:
    cpu = _component_for_role(selection, components_by_id, "cpu")
    motherboard = _component_for_role(selection, components_by_id, "motherboard")
    if cpu is None or motherboard is None:
        return []

    cpu_perf = _int_spec(cpu, "perf_index")
    chipset = _string_spec(motherboard, "chipset").upper()
    if cpu_perf <= 0 or not chipset:
        return []

    if cpu_perf >= 90 and chipset.startswith(("H", "A")):
        return [
            CompatibilityFinding(
                level="warning",
                code="cpu_motherboard_tier",
                title="高端 CPU 搭配入门主板",
                detail=f"{motherboard.name} 属于入门主板，搭配 {cpu.name} 这类高性能 CPU 时供电和扩展性偏保守。",
                component_ids=[cpu.id, motherboard.id],
            )
        ]
    return []


def _finding_counts(findings: List[CompatibilityFinding]) -> Dict[FindingLevel, int]:
    return {
        "pass": sum(finding.level == "pass" for finding in findings),
        "warning": sum(finding.level == "warning" for finding in findings),
        "error": sum(finding.level == "error" for finding in findings),
    }


def _checked_rule_codes(findings: List[CompatibilityFinding]) -> List[str]:
    return sorted({finding.code for finding in findings})


def _component_for_role(
    selection: BuildSelection,
    components_by_id: Dict[str, HardwareComponent],
    role: str,
) -> Optional[HardwareComponent]:
    component_id = selection.component_id(role)
    if not component_id:
        return None
    return components_by_id.get(component_id)


def _string_spec(component: HardwareComponent, key: str) -> str:
    value = component.specs.get(key)
    return value if isinstance(value, str) else ""


def _int_spec(component: HardwareComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0
