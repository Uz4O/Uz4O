from typing import Dict, List, Optional

from pydantic import BaseModel


class GuideStepContent(BaseModel):
    id: str
    number: int
    title: str
    summary: str
    action: str
    caution: str
    symbol: str


class GuideInstallPhase(BaseModel):
    id: str
    title: str
    subtitle: str
    symbol: str


class GuideComponentDetailPoint(BaseModel):
    id: str
    title: str
    text: str
    symbol: str


class GuideComponentIntroItem(BaseModel):
    id: str
    title: str
    subtitle: str
    symbol: str
    image_name: str
    model_name: Optional[str] = None
    detail_points: List[GuideComponentDetailPoint]


class GuideIntro(BaseModel):
    title: str
    subtitle: str


class InteractiveInstall(BaseModel):
    model_names: List[str]
    phases: List[GuideInstallPhase]
    animated_board_node_names: List[str] = []
    anchor_name: Optional[str] = None
    anchor_names: List[str] = []
    reset_scene_phase_index: Optional[int] = None


class GuideContentResponse(BaseModel):
    version: str
    intro: GuideIntro
    component_intro_items: List[GuideComponentIntroItem]
    assembly_steps: List[GuideStepContent]
    interactive_installs: Dict[str, InteractiveInstall]


CPU_INSTALL_PHASES = [
    GuideInstallPhase(
        id="position-board",
        title="摆正主板",
        subtitle="先确认 AM5 插槽位置",
        symbol="rectangle.3.group",
    ),
    GuideInstallPhase(
        id="lift-lever",
        title="抬起拉杆",
        subtitle="向外拨开再向上抬起",
        symbol="arrow.up.right",
    ),
    GuideInstallPhase(
        id="open-frame",
        title="打开压框",
        subtitle="翻开金属压框，露出触点",
        symbol="rectangle.portrait.rotate",
    ),
    GuideInstallPhase(
        id="align",
        title="对准三角",
        subtitle="CPU 角标对准插槽角标",
        symbol="triangle.fill",
    ),
    GuideInstallPhase(
        id="seat-lock",
        title="轻放并锁紧",
        subtitle="自然落入后压回拉杆",
        symbol="checkmark",
    ),
]

MEMORY_INSTALL_PHASES = [
    GuideInstallPhase(
        id="open",
        title="打开卡扣",
        subtitle="优先打开 2/4 槽位卡扣",
        symbol="arrow.up.left.and.arrow.up.right",
    ),
    GuideInstallPhase(
        id="inspect-notch",
        title="查看防呆口",
        subtitle="先看清内存金手指缺口",
        symbol="magnifyingglass",
    ),
    GuideInstallPhase(
        id="align-slot",
        title="对齐插槽",
        subtitle="缺口对准主板插槽凸点",
        symbol="rectangle.and.text.magnifyingglass",
    ),
    GuideInstallPhase(
        id="install",
        title="安装两条内存",
        subtitle="两条都对准后垂直压入",
        symbol="rectangle.stack.badge.plus",
    ),
    GuideInstallPhase(
        id="press-lock",
        title="下压回弹",
        subtitle="两端下压，卡扣自动回弹",
        symbol="checkmark",
    ),
]

SSD_INSTALL_PHASES = [
    GuideInstallPhase(
        id="remove-heatsink",
        title="拆下散热片",
        subtitle="先卸下 M.2 散热片和固定螺丝",
        symbol="screwdriver",
    ),
    GuideInstallPhase(
        id="align-notch",
        title="对齐缺口",
        subtitle="金手指缺口对准 M.2 插槽",
        symbol="rectangle.and.text.magnifyingglass",
    ),
    GuideInstallPhase(
        id="insert-angle",
        title="斜插 SSD",
        subtitle="约 30 度角轻轻插入插槽",
        symbol="arrow.down.forward",
    ),
    GuideInstallPhase(
        id="press-fix",
        title="压平固定",
        subtitle="压平尾端后拧紧固定螺丝",
        symbol="arrow.down.to.line.compact",
    ),
    GuideInstallPhase(
        id="reinstall-heatsink",
        title="装回散热片",
        subtitle="撕掉导热垫保护膜再装回",
        symbol="checkmark",
    ),
]

COMPONENT_INTRO_ITEMS = [
    GuideComponentIntroItem(
        id="cpu",
        title="CPU",
        subtitle="负责运算处理",
        symbol="cpu",
        image_name="GuidePartCPU",
        model_name="desktop-cpu-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="方形芯片，上表面有型号标识，底部有密集触点。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="安装在主板的 CPU 插槽上，并固定散热器。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="gpu",
        title="显卡",
        subtitle="负责图形输出",
        symbol="display",
        image_name="GuidePartGPU",
        model_name="dual-fan-gpu-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="长条板卡，带风扇、金手指和视频输出接口。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="插在主板 PCIe 插槽，并固定在机箱挡板。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="board",
        title="主板",
        subtitle="连接所有配件",
        symbol="rectangle.3.group",
        image_name="GuidePartBoard",
        model_name="modern-atx-motherboard-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="大块电路板，上面有 CPU、内存、显卡和硬盘插槽。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="固定在机箱铜柱上，接口朝向机箱背部。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="memory",
        title="内存",
        subtitle="临时存储数据",
        symbol="rectangle.stack",
        image_name="GuidePartMemory",
        model_name="desktop-dimm-ram-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="细长条形模块，底部有金手指和防呆缺口。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="插入主板内存插槽，听到卡扣回弹即可。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="ssd",
        title="SSD",
        subtitle="存放系统与文件",
        symbol="externaldrive",
        image_name="GuidePartSSD",
        model_name="m2-2280-nvme-ssd-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="小型硬盘模块，常见 M.2 条形或 2.5 英寸方形。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="M.2 SSD 斜插主板插槽后压平固定。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="psu",
        title="电源",
        subtitle="为整机供电",
        symbol="bolt",
        image_name="GuidePartPSU",
        model_name="atx-psu-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="黑色金属盒，带风扇、电源接口和多组线材。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="固定在机箱电源仓，风扇朝向通风口。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="cooler",
        title="散热器",
        subtitle="帮助处理器散热",
        symbol="fan",
        image_name="GuidePartCooler",
        model_name="tower-cpu-air-cooler-mobile",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="由风扇、鳍片和热管组成，底部接触 CPU。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="压在 CPU 上方，风扇线接到 CPU_FAN。",
                symbol="mappin.circle",
            ),
        ],
    ),
    GuideComponentIntroItem(
        id="case",
        title="机箱",
        subtitle="安装并保护配件",
        symbol="shippingbox",
        image_name="GuidePartCase",
        detail_points=[
            GuideComponentDetailPoint(
                id="appearance",
                title="外观识别",
                text="电脑外壳，内部有主板位、电源仓和风扇位。",
                symbol="magnifyingglass",
            ),
            GuideComponentDetailPoint(
                id="install",
                title="安装位置",
                text="所有核心配件最终都会固定在机箱内部。",
                symbol="mappin.circle",
            ),
        ],
    ),
]

ASSEMBLY_STEPS = [
    GuideStepContent(
        id="cpu",
        number=1,
        title="安装 CPU",
        summary="将 CPU 放入主板插槽",
        action="抬起拉杆并打开压框，对准三角标记后轻放 CPU",
        caution="不要触碰插槽触点，不要用力按压",
        symbol="cpu",
    ),
    GuideStepContent(
        id="memory",
        number=2,
        title="安装内存",
        summary="对准缺口后压入插槽",
        action="优先安装 2/4 槽位，双手均匀下压到卡扣回弹",
        caution="没有对准缺口时不要强压",
        symbol="rectangle.stack",
    ),
    GuideStepContent(
        id="ssd",
        number=3,
        title="安装 SSD",
        summary="固定 M.2 固态硬盘",
        action="斜插 SSD，压平后用螺丝固定",
        caution="散热片胶膜要撕掉",
        symbol="externaldrive",
    ),
    GuideStepContent(
        id="cooler",
        number=4,
        title="安装散热器",
        summary="涂硅脂并压紧散热器",
        action="涂黄豆大小硅脂，对角拧紧散热器",
        caution="风扇线要接 CPU_FAN",
        symbol="fan",
    ),
    GuideStepContent(
        id="board",
        number=5,
        title="主板入箱",
        summary="把主板固定到机箱",
        action="确认铜柱位置，对齐背部接口后固定螺丝",
        caution="多余铜柱可能造成短路",
        symbol="rectangle.3.group",
    ),
    GuideStepContent(
        id="psu",
        number=6,
        title="安装电源",
        summary="固定电源并预留线材",
        action="确认风扇朝向，固定电源，预留主供电线",
        caution="模组线不要混用其他品牌",
        symbol="bolt",
    ),
    GuideStepContent(
        id="cables",
        number=7,
        title="接电源线",
        summary="连接主板和机箱线",
        action="接 24pin、CPU 8pin、前面板和风扇线",
        caution="CPU 供电和显卡供电不要插错",
        symbol="cable.connector",
    ),
    GuideStepContent(
        id="gpu",
        number=8,
        title="安装显卡",
        summary="把显卡插入 PCIe 插槽",
        action="打开卡扣，插入显卡，固定挡板螺丝",
        caution="显示器线要接到显卡接口",
        symbol="display",
    ),
    GuideStepContent(
        id="boot",
        number=9,
        title="首次开机",
        summary="检查是否能点亮",
        action="接显示器键盘，打开电源，按机箱开机键",
        caution="首次开机可能会训练内存较久",
        symbol="power",
    ),
    GuideStepContent(
        id="finish",
        number=10,
        title="收尾检查",
        summary="检查温度和线材",
        action="确认硬件识别、温度正常，再整理线材",
        caution="不要带电整理机箱内部线材",
        symbol="checkmark.seal",
    ),
]


def get_guide_content() -> GuideContentResponse:
    return GuideContentResponse(
        version="2026-06-16",
        intro=GuideIntro(
            title="先认识这些配件",
            subtitle="了解常见配件的外观和作用，为接下来的装机步骤打好基础。",
        ),
        component_intro_items=COMPONENT_INTRO_ITEMS,
        assembly_steps=ASSEMBLY_STEPS,
        interactive_installs={
            "cpu": InteractiveInstall(
                model_names=["modern-atx-motherboard-mobile", "desktop-cpu-mobile"],
                phases=CPU_INSTALL_PHASES,
                animated_board_node_names=[
                    "MB_CPU_Load_Lever",
                    "MB_CPU_Lever_Handle",
                    "MB_CPU_Metal_Frame_Top",
                    "MB_CPU_Metal_Frame_Bottom",
                    "MB_CPU_Metal_Frame_Left",
                    "MB_CPU_Metal_Frame_Right",
                ],
                anchor_name="cpuSocketInstallAnchor",
                reset_scene_phase_index=len(CPU_INSTALL_PHASES),
            ),
            "memory": InteractiveInstall(
                model_names=[
                    "modern-atx-motherboard-mobile",
                    "desktop-cpu-mobile",
                    "desktop-dimm-ram-mobile",
                ],
                phases=MEMORY_INSTALL_PHASES,
                animated_board_node_names=[
                    "MB_RAM_Top_Latch_2",
                    "MB_RAM_Top_Latch_Lever_2",
                    "MB_RAM_Top_Latch_Hook_2",
                    "MB_RAM_Top_Latch_Notch_2",
                    "MB_RAM_Bottom_Latch_2",
                    "MB_RAM_Bottom_Latch_Lever_2",
                    "MB_RAM_Bottom_Latch_Hook_2",
                    "MB_RAM_Bottom_Latch_Notch_2",
                    "MB_RAM_Top_Latch_4",
                    "MB_RAM_Top_Latch_Lever_4",
                    "MB_RAM_Top_Latch_Hook_4",
                    "MB_RAM_Top_Latch_Notch_4",
                    "MB_RAM_Bottom_Latch_4",
                    "MB_RAM_Bottom_Latch_Lever_4",
                    "MB_RAM_Bottom_Latch_Hook_4",
                    "MB_RAM_Bottom_Latch_Notch_4",
                ],
                anchor_names=["dimmSlotA2InstallAnchor", "dimmSlotB2InstallAnchor"],
            ),
            "ssd": InteractiveInstall(
                model_names=[
                    "modern-atx-motherboard-mobile",
                    "desktop-cpu-mobile",
                    "desktop-dimm-ram-mobile",
                    "m2-2280-nvme-ssd-mobile",
                ],
                phases=SSD_INSTALL_PHASES,
                anchor_name="m2SlotInstallAnchor",
            ),
        },
    )
