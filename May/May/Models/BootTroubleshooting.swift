import Foundation

struct BootTroubleshootingChoice: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let outcomeID: String
}

struct BootTroubleshootingScenario: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let question: String
    let questionHint: String
    let choices: [BootTroubleshootingChoice]
}

struct BootTroubleshootingStep: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let warning: String?

    init(
        id: String,
        title: String,
        detail: String,
        symbol: String,
        warning: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.warning = warning
    }
}

struct BootTroubleshootingOutcome: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let estimatedMinutes: Int
    let steps: [BootTroubleshootingStep]
}

enum BootTroubleshootingStage: Equatable, Sendable {
    case symptoms
    case question
    case action
    case resolved
    case unresolved
}

struct BootTroubleshootingSession: Equatable, Sendable {
    private(set) var stage: BootTroubleshootingStage = .symptoms
    private(set) var selectedScenarioID: String?
    private(set) var selectedChoiceID: String?
    private(set) var currentStepIndex = 0
    private(set) var completedStepIDs: Set<String> = []

    var selectedScenario: BootTroubleshootingScenario? {
        BootTroubleshootingCatalog.scenario(id: selectedScenarioID)
    }

    var selectedChoice: BootTroubleshootingChoice? {
        selectedScenario?.choices.first { $0.id == selectedChoiceID }
    }

    var outcome: BootTroubleshootingOutcome? {
        BootTroubleshootingCatalog.outcome(id: selectedChoice?.outcomeID)
    }

    var currentStep: BootTroubleshootingStep? {
        guard let outcome, outcome.steps.indices.contains(currentStepIndex) else { return nil }
        return outcome.steps[currentStepIndex]
    }

    var progress: Double {
        guard let outcome, !outcome.steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(outcome.steps.count)
    }

    mutating func selectScenario(_ id: String) {
        guard BootTroubleshootingCatalog.scenario(id: id) != nil else { return }
        selectedScenarioID = id
        selectedChoiceID = nil
        currentStepIndex = 0
        completedStepIDs = []
    }

    mutating func beginQuestions() {
        guard selectedScenario != nil else { return }
        stage = .question
    }

    mutating func selectChoice(_ id: String) {
        guard let choice = selectedScenario?.choices.first(where: { $0.id == id }),
              BootTroubleshootingCatalog.outcome(id: choice.outcomeID) != nil else { return }
        selectedChoiceID = id
        currentStepIndex = 0
        completedStepIDs = []
        stage = .action
    }

    mutating func markResolved() {
        guard stage == .action else { return }
        if let currentStep { completedStepIDs.insert(currentStep.id) }
        stage = .resolved
    }

    mutating func continueUnresolved() {
        guard stage == .action, let outcome, let currentStep else { return }
        completedStepIDs.insert(currentStep.id)
        if outcome.steps.indices.contains(currentStepIndex + 1) {
            currentStepIndex += 1
        } else {
            stage = .unresolved
        }
    }

    mutating func goBack() {
        switch stage {
        case .symptoms:
            break
        case .question:
            selectedScenarioID = nil
            selectedChoiceID = nil
            stage = .symptoms
        case .action:
            selectedChoiceID = nil
            currentStepIndex = 0
            completedStepIDs = []
            stage = .question
        case .resolved, .unresolved:
            stage = .action
        }
    }

    mutating func restart() {
        self = BootTroubleshootingSession()
    }
}

enum BootTroubleshootingCatalog {
    static let safetyNotice = "出现焦味、火花、液体或异常高温时，请立即断电并停止操作；不要拆开电源。"

    static let scenarios: [BootTroubleshootingScenario] = [
        BootTroubleshootingScenario(
            id: "no-power",
            title: "完全没反应",
            subtitle: "按下开机键，风扇和灯都不亮",
            symbol: "power",
            question: "按下开机键后，主机会怎样？",
            questionHint: "观察风扇和机箱灯，不需要拆机。",
            choices: [
                .init(id: "dead", title: "完全没有反应", outcomeID: "no-power-dead"),
                .init(id: "pulse", title: "转一下或亮一下就停", outcomeID: "power-pulse"),
                .init(id: "unknown", title: "我不确定", outcomeID: "no-power-dead")
            ]
        ),
        BootTroubleshootingScenario(
            id: "no-display",
            title: "风扇转，但没有画面",
            subtitle: "电脑似乎启动了，显示器却没信号",
            symbol: "display",
            question: "显示器线接在哪里？",
            questionHint: "查看机箱背面的视频线位置。",
            choices: [
                .init(id: "motherboard", title: "主板接口", outcomeID: "video-port"),
                .init(id: "gpu", title: "独立显卡接口", outcomeID: "no-display-general"),
                .init(id: "unknown", title: "看不出来", outcomeID: "video-port")
            ]
        ),
        BootTroubleshootingScenario(
            id: "restart-loop",
            title: "开机后反复重启",
            subtitle: "启动几秒后关机，再自动启动",
            symbol: "arrow.clockwise",
            question: "通常在什么时候重启？",
            questionHint: "选择最接近的情况即可。",
            choices: [
                .init(id: "before-bios", title: "出现主板画面之前", outcomeID: "restart-hardware"),
                .init(id: "in-system", title: "进入 Windows 时", outcomeID: "restart-system"),
                .init(id: "under-load", title: "玩游戏或高负载时", outcomeID: "restart-load"),
                .init(id: "unknown", title: "没有规律", outcomeID: "restart-hardware")
            ]
        ),
        BootTroubleshootingScenario(
            id: "debug-light",
            title: "主板故障灯一直亮",
            subtitle: "CPU、DRAM、VGA 或 BOOT 灯常亮",
            symbol: "light.beacon.max",
            question: "哪一颗故障灯一直亮？",
            questionHint: "标签通常印在主板右侧或内存插槽附近。",
            choices: [
                .init(id: "cpu", title: "CPU", outcomeID: "debug-cpu"),
                .init(id: "dram", title: "DRAM", outcomeID: "debug-dram"),
                .init(id: "vga", title: "VGA", outcomeID: "debug-vga"),
                .init(id: "boot", title: "BOOT", outcomeID: "debug-boot"),
                .init(id: "unknown", title: "看不清或没有标注", outcomeID: "debug-unknown")
            ]
        ),
        BootTroubleshootingScenario(
            id: "bios-no-system",
            title: "能进 BIOS，进不了系统",
            subtitle: "停在 BIOS 或提示找不到启动设备",
            symbol: "externaldrive.badge.questionmark",
            question: "BIOS 里能看到系统硬盘吗？",
            questionHint: "可以在 Storage、NVMe 或 SATA 页面查看。",
            choices: [
                .init(id: "visible", title: "可以看到", outcomeID: "boot-order"),
                .init(id: "missing", title: "看不到", outcomeID: "drive-missing"),
                .init(id: "unknown", title: "不会查看", outcomeID: "drive-missing")
            ]
        ),
        BootTroubleshootingScenario(
            id: "hardware-missing",
            title: "识别不到硬件",
            subtitle: "装好后少了硬盘、内存或显卡",
            symbol: "questionmark.square.dashed",
            question: "电脑识别不到什么？",
            questionHint: "选择主要问题，其他硬件可以稍后重新排查。",
            choices: [
                .init(id: "storage", title: "硬盘", outcomeID: "drive-missing"),
                .init(id: "memory", title: "内存容量不对", outcomeID: "memory-missing"),
                .init(id: "gpu", title: "独立显卡", outcomeID: "gpu-missing"),
                .init(id: "other", title: "其他硬件", outcomeID: "other-missing")
            ]
        )
    ]

    static let outcomes: [BootTroubleshootingOutcome] = [
        BootTroubleshootingOutcome(
            id: "no-power-dead",
            title: "先检查供电链路",
            summary: "完全无反应通常先从墙插、电源开关和主板供电检查。",
            estimatedMinutes: 5,
            steps: [
                step("wall-power", "确认墙插和插排有电", "用手机充电器等低风险设备确认当前插座确实供电。", "poweroutlet.type.b"),
                step("psu-switch", "检查电源线和背部开关", "确认电源线两端插紧，并将电源背部 I/O 开关拨到 I。", "switch.2"),
                step("board-power", "检查主板 24Pin 和 CPU 8Pin", "断电并拔掉电源线后，按一下机箱开机键放电，再确认两组供电插头完全插入。", "bolt.horizontal", warning: "只检查外部插头，不要拆开电源。"),
                step("front-panel", "核对机箱开机线", "按主板说明书确认 POWER SW 插在正确针脚；不要尝试碰触其他针脚。", "button.programmable", warning: "看不清针脚时停止操作并请熟悉装机的人协助。"),
                step("no-power-service", "仍无反应时停止继续拆装", "可能涉及电源、主板或机箱开关故障，建议携带已检查项目交给售后检测。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "power-pulse",
            title: "优先排查内存和供电保护",
            summary: "转一下就停常见于内存未插紧、供电线松动或散热安装异常。",
            estimatedMinutes: 10,
            steps: [
                step("pulse-discharge", "先完全断电", "关闭电源背部开关，拔掉电源线并按机箱开机键 5 秒。", "power", warning: "闻到焦味或看到火花时不要继续。"),
                step("pulse-memory", "只留一根内存在 A2 插槽", "重新安装一根内存，确认两端卡扣完全锁住；A2 通常是离 CPU 第二个插槽。", "memorychip", warning: "操作前触碰机箱金属部分释放静电。"),
                step("pulse-power", "重新确认两组主板供电", "检查主板 24Pin 和 CPU 8Pin 是否插到底，不要混用 CPU 与显卡供电线。", "bolt.horizontal"),
                step("pulse-cooler", "查看 CPU 风扇和散热器", "确认 CPU 风扇接在 CPU_FAN，散热器没有明显歪斜或松动。", "fan"),
                step("pulse-service", "仍然秒断时交给售后检测", "不要反复强行开机，也不要自行拆开电源或拆下 CPU。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "video-port",
            title: "视频线可能接错位置",
            summary: "安装独立显卡后，显示器通常应连接显卡的视频接口。",
            estimatedMinutes: 3,
            steps: [
                step("gpu-video-port", "将视频线连接到独立显卡", "显卡接口通常横向排列在机箱下半部；不要接主板上方的 HDMI 或 DP。", "rectangle.connected.to.line.below"),
                step("monitor-source", "切换显示器输入源", "用显示器按键选择与线材一致的 HDMI 或 DP 输入。", "display"),
                step("display-cable", "重新插拔或更换视频线", "关闭电脑和显示器后重新插紧两端，也可以换一个显卡接口测试。", "cable.connector"),
                step("gpu-power", "确认显卡供电线插紧", "断电后检查显卡 6Pin、8Pin 或 12V-2x6 插头是否完全到位。", "bolt", warning: "不要带电插拔显卡或供电线。"),
                step("video-service", "仍无画面时记录故障灯", "查看主板 CPU、DRAM、VGA、BOOT 灯并重新选择对应排查入口。", "light.beacon.max")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "no-display-general",
            title: "先排除显示链路和内存接触",
            summary: "连接位置正确时，按显示器、显卡供电、内存和故障灯顺序检查。",
            estimatedMinutes: 10,
            steps: [
                step("display-source-cable", "确认输入源、线材和接口", "切换正确输入源，重新插拔视频线，并尝试显卡上的另一个接口。", "display"),
                step("display-gpu-power", "检查显卡供电", "断电后确认显卡供电插头完全插入，转接线没有明显松动或弯折。", "bolt", warning: "不要带电插拔。"),
                step("display-memory", "只留一根内存在 A2 插槽", "断电放电后重新安装一根内存，确认卡扣完全锁住。", "memorychip"),
                step("display-debug", "查看主板故障灯", "记录停在 CPU、DRAM、VGA 还是 BOOT，再从故障灯入口继续。", "light.beacon.max"),
                step("display-service", "仍无画面时停止反复开机", "建议让售后分别检测显卡、内存和主板，不要自行拆下 CPU。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "restart-hardware",
            title: "优先排查内存与基础供电",
            summary: "进入系统前重启通常先检查内存训练、供电和散热安装。",
            estimatedMinutes: 12,
            steps: [
                step("restart-wait", "新装 DDR5 先等待内存训练", "首次开机可能黑屏并自动重启数次，保持供电并等待最多 5 分钟。", "clock", warning: "出现焦味、火花或异常声响时立即断电。"),
                step("restart-memory", "单根内存测试 A2 插槽", "断电放电后只安装一根内存，确认卡扣锁住，再分别测试每根内存。", "memorychip"),
                step("restart-power", "复查主板和显卡供电", "确认 CPU 8Pin、主板 24Pin 和显卡供电全部插到底。", "bolt.horizontal"),
                step("restart-cooling", "确认 CPU_FAN 正常转动", "检查风扇接线和散热器是否明显松动；不要在反复断电状态下持续尝试。", "fan"),
                step("restart-service", "仍循环重启时送检", "记录每次重启前的故障灯位置，交给售后分别检测内存、主板和电源。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "restart-system",
            title: "先检查系统启动环境",
            summary: "进入 Windows 阶段才重启，更可能与驱动、更新或系统盘有关。",
            estimatedMinutes: 15,
            steps: [
                step("system-external", "拔掉非必要 USB 设备", "只保留键盘、鼠标和显示器后重新启动，排除外接设备影响。", "usb"),
                step("system-repair", "进入 Windows 启动修复", "连续启动失败后使用系统提供的启动修复，不要选择清除个人文件。", "cross.case"),
                step("system-driver", "撤销最近的驱动或系统改动", "如果问题刚出现，可在安全模式卸载最近显卡驱动或系统更新。", "arrow.uturn.backward"),
                step("system-drive", "检查系统盘状态", "在 BIOS 中确认系统盘稳定识别；时有时无通常需要重新安装或送检硬盘。", "internaldrive"),
                step("system-service", "无法安全进入系统时先备份", "停止反复强制关机，优先让售后备份重要数据并检查系统盘。", "externaldrive.badge.exclamationmark")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "restart-load",
            title: "优先检查温度和高负载供电",
            summary: "游戏或渲染时重启，常见于过热、显卡供电松动或电源能力不足。",
            estimatedMinutes: 10,
            steps: [
                step("load-vents", "确认风扇转动和风道畅通", "观察 CPU、显卡和机箱风扇，清理堵住进出风口的灰尘或遮挡。", "fan"),
                step("load-temperature", "查看 CPU 和显卡温度", "使用已有监控软件复现一次；温度快速接近上限时立即停止负载。", "thermometer.high", warning: "不要为了测试而持续运行会触发重启的负载。"),
                step("load-gpu-power", "复查显卡供电线", "断电后确认插头完全到位；高功耗显卡按电源厂商说明使用独立线材。", "bolt"),
                step("load-psu", "核对电源额定功率和接口", "对照 CPU、显卡官方需求和电源型号，不要仅凭外壳标注判断质量。", "powerplug"),
                step("load-service", "仍在负载下重启时送检", "停止继续压力测试，让售后检查散热接触、电源和显卡稳定性。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "debug-cpu",
            title: "CPU 灯：先检查供电和散热接线",
            summary: "CPU 灯不等于 CPU 一定损坏，先排除供电和基础安装问题。",
            estimatedMinutes: 8,
            steps: [
                step("cpu-eps", "检查 CPU 8Pin 供电", "断电后确认主板顶部 CPU/EPS 供电插紧，不能误用显卡 PCIe 线。", "bolt.horizontal"),
                step("cpu-fan", "确认 CPU_FAN 已连接", "检查散热风扇插在 CPU_FAN，散热器没有明显歪斜或松动。", "fan"),
                step("cpu-bios", "使用主板官方恢复方式", "有独立 Clear CMOS 按钮时按说明书操作；没有按钮则不要自行碰触针脚。", "arrow.counterclockwise"),
                step("cpu-support", "仍亮 CPU 灯时停止拆装", "可能需要检查 BIOS 支持、CPU 插座或主板，建议交给售后处理。", "wrench.and.screwdriver", warning: "新手不要自行拆下 CPU 或触碰插座针脚。")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "debug-dram",
            title: "DRAM 灯：优先检查内存安装",
            summary: "DRAM 灯常见于内存未插紧、插槽顺序不对或训练未完成。",
            estimatedMinutes: 10,
            steps: [
                step("dram-wait", "新装 DDR5 先等待训练", "首次开机保持供电并等待最多 5 分钟，期间可能重启数次。", "clock"),
                step("dram-a2", "单根内存安装到 A2", "断电放电后只留一根内存，按压到卡扣完全锁住。", "memorychip"),
                step("dram-sticks", "分别测试每根内存", "使用同一推荐插槽逐根测试，记录是哪根或哪个插槽无法启动。", "square.grid.2x2"),
                step("dram-profile", "关闭 XMP 或 EXPO", "能进 BIOS 时恢复默认内存参数，先确认默认频率可以稳定启动。", "gauge.with.dots.needle.33percent"),
                step("dram-service", "仍亮灯时核对兼容性", "根据主板内存支持列表核对型号，必要时让售后检测内存和主板。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "debug-vga",
            title: "VGA 灯：优先检查显卡连接",
            summary: "VGA 灯通常与显卡安装、供电或视频输出链路有关。",
            estimatedMinutes: 10,
            steps: [
                step("vga-output", "确认视频线接在独立显卡", "显示器线应连接显卡接口，并选择正确输入源。", "display"),
                step("vga-power", "检查显卡供电", "断电后确认所有显卡供电插头完全插入，转接头没有松动。", "bolt", warning: "不要带电插拔。"),
                step("vga-reseat", "重新安装显卡", "断电放电后解锁 PCIe 卡扣，垂直取出并重新压入主插槽。", "rectangle.stack", warning: "不熟悉卡扣位置时不要硬拔，请让售后协助。"),
                step("vga-light", "观察 VGA 灯是否熄灭", "重新开机后等待一分钟；若仍常亮，记录显卡风扇和灯光状态。", "light.beacon.max"),
                step("vga-service", "仍亮 VGA 灯时交叉检测", "需要用其他显卡或主机确认故障，建议交给售后完成。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "debug-boot",
            title: "BOOT 灯：检查启动硬盘",
            summary: "BOOT 灯表示主板未找到可启动系统，不代表 CPU 或显卡故障。",
            estimatedMinutes: 8,
            steps: [
                step("boot-bios-drive", "确认 BIOS 能看到系统盘", "在 Storage、NVMe 或 SATA 页面查看硬盘型号是否出现。", "internaldrive"),
                step("boot-manager", "选择 Windows Boot Manager", "在启动顺序中将系统盘对应的 Windows Boot Manager 设为第一项。", "list.number"),
                step("boot-usb", "拔掉其他 U 盘和移动硬盘", "只保留系统盘后重新启动，避免启动顺序被外接设备影响。", "usb"),
                step("boot-repair", "使用系统启动修复", "硬盘可识别但无法进入系统时，使用 Windows 安装介质的启动修复。", "cross.case"),
                step("boot-service", "仍失败时优先保护数据", "不要格式化有重要数据的系统盘，先交给售后备份和检测。", "externaldrive.badge.exclamationmark")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "debug-unknown",
            title: "先确认故障灯标签",
            summary: "不同主板灯位不同，先记录常亮位置再继续对应检查。",
            estimatedMinutes: 5,
            steps: [
                step("light-wait", "先等待一次完整自检", "新装 DDR5 平台首次开机可等待最多 5 分钟，不要中途频繁断电。", "clock"),
                step("light-label", "寻找灯旁的小字", "用手机灯光查看 CPU、DRAM、VGA、BOOT 标注，并拍照放大。", "camera.macro"),
                step("light-manual", "查看主板说明书", "搜索主板型号和 Debug LED 页面，确认灯位含义。", "book.closed"),
                step("light-return", "返回选择对应故障灯", "确认标签后重新开始排查，选择 CPU、DRAM、VGA 或 BOOT。", "arrow.uturn.backward"),
                step("light-service", "无法确认时不要盲目拆装", "把故障灯照片和主板型号交给售后判断。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "boot-order",
            title: "系统盘可能没有被设为启动项",
            summary: "BIOS 能看到硬盘时，优先检查启动顺序和系统引导。",
            estimatedMinutes: 8,
            steps: [
                step("order-manager", "选择 Windows Boot Manager", "在 Boot 页面将系统盘对应的 Windows Boot Manager 设置为第一启动项。", "list.number"),
                step("order-external", "拔掉其他存储设备", "移除 U 盘和移动硬盘后重新启动，避免选错启动盘。", "usb"),
                step("order-uefi", "恢复主板默认启动模式", "如果曾修改 CSM 或 UEFI 设置，先恢复主板默认值再试。", "gearshape.2"),
                step("order-repair", "运行 Windows 启动修复", "仍无法启动时使用安装介质修复引导，不要直接格式化硬盘。", "cross.case"),
                step("order-service", "重要数据优先备份", "修复前如有重要文件，先让售后读取和备份系统盘。", "externaldrive.badge.exclamationmark")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "drive-missing",
            title: "硬盘连接或插槽可能需要检查",
            summary: "BIOS 看不到硬盘时，先检查安装和主板插槽设置。",
            estimatedMinutes: 10,
            steps: [
                step("drive-bios", "确认所有存储页面都没有硬盘", "分别查看 NVMe、SATA 和 Storage 页面，避免只看启动项。", "internaldrive"),
                step("drive-poweroff", "断电后重新安装硬盘", "M.2 硬盘应平放固定；SATA 硬盘需要同时连接数据线和电源线。", "internaldrive", warning: "操作前断电、拔线并放电。"),
                step("drive-slot", "尝试主板支持的另一个插槽", "按说明书确认插槽支持当前 SATA 或 NVMe 类型，部分插槽会共享通道。", "square.grid.3x3"),
                step("drive-settings", "恢复 BIOS 默认存储设置", "如果修改过 RAID、VMD 或存储模式，先恢复默认设置再检测。", "gearshape.2"),
                step("drive-service", "仍不识别时停止反复安装", "需要用另一台电脑或硬盘盒交叉检测，重要数据请优先交给专业人员。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "memory-missing",
            title: "先确认内存安装和插槽",
            summary: "容量少一半通常与单根内存或单个插槽未识别有关。",
            estimatedMinutes: 10,
            steps: [
                step("memory-bios", "先看 BIOS 识别容量", "如果 BIOS 已识别完整容量，问题更可能在系统设置而不是安装。", "memorychip"),
                step("memory-reseat", "重新安装未识别的内存", "断电放电后按主板推荐顺序安装，确保两端卡扣锁住。", "memorychip", warning: "操作前触碰机箱金属部分释放静电。"),
                step("memory-each", "逐根测试同一插槽", "在 A2 插槽分别测试每根内存，记录是否有单根始终不识别。", "square.grid.2x2"),
                step("memory-default", "恢复默认内存频率", "关闭 XMP 或 EXPO，先确认默认参数下容量完整且稳定。", "gauge.with.dots.needle.33percent"),
                step("memory-service", "仍缺失时检测内存和主板", "不要自行处理 CPU 插座针脚，让售后完成插槽和平台检测。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "gpu-missing",
            title: "先检查显卡安装、供电和驱动",
            summary: "系统识别不到显卡时，先排除物理连接，再处理驱动。",
            estimatedMinutes: 12,
            steps: [
                step("missing-gpu-power", "检查显卡供电和指示灯", "断电后确认全部供电插头插紧，转接线没有明显松动。", "bolt"),
                step("missing-gpu-reseat", "重新安装显卡", "断电放电后重新将显卡压入主 PCIe 插槽并固定挡板螺丝。", "rectangle.stack", warning: "不熟悉 PCIe 卡扣时不要硬拔。"),
                step("missing-gpu-bios", "查看 BIOS 是否识别 PCIe 设备", "恢复默认 PCIe 设置，不要强制修改不理解的通道模式。", "gearshape.2"),
                step("missing-gpu-driver", "安装显卡厂商官方驱动", "进入系统后只使用 NVIDIA、AMD 或 Intel 官方驱动安装程序。", "shippingbox"),
                step("missing-gpu-service", "仍不识别时交叉检测", "需要另一台电脑或显卡确认硬件状态，建议交给售后。", "wrench.and.screwdriver")
            ]
        ),
        BootTroubleshootingOutcome(
            id: "other-missing",
            title: "先确认连接和主板支持范围",
            summary: "其他硬件未识别时，优先核对连接、插槽和说明书。",
            estimatedMinutes: 8,
            steps: [
                step("other-restart", "完全关机后重新启动", "关闭系统并断开电源 30 秒，再重新开机确认是否仍未识别。", "power"),
                step("other-connection", "检查对应线材和插槽", "断电后重新安装设备，确认数据线和供电线均已连接。", "cable.connector"),
                step("other-manual", "查看主板说明书的共享限制", "部分 M.2、SATA 和 PCIe 插槽不能同时使用，以说明书为准。", "book.closed"),
                step("other-default", "恢复 BIOS 默认设置", "撤销不确定的手动设置，再查看设备是否出现。", "arrow.counterclockwise"),
                step("other-service", "仍不识别时记录型号并送检", "记录主板、设备型号和已检查项目，让售后进行兼容性和硬件检测。", "wrench.and.screwdriver")
            ]
        )
    ]

    static func scenario(id: String?) -> BootTroubleshootingScenario? {
        scenarios.first { $0.id == id }
    }

    static func outcome(id: String?) -> BootTroubleshootingOutcome? {
        outcomes.first { $0.id == id }
    }

    private static func step(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ symbol: String,
        warning: String? = nil
    ) -> BootTroubleshootingStep {
        BootTroubleshootingStep(
            id: id,
            title: title,
            detail: detail,
            symbol: symbol,
            warning: warning
        )
    }
}
