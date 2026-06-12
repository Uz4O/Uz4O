import Foundation

struct GuideStepContent: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let summary: String
    let action: String
    let caution: String
    let symbol: String
}

struct CPUInstallPhase: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
}

struct GuideComponentIntroItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let imageName: String
    let detailPoints: [GuideComponentDetailPoint]
}

struct GuideComponentDetailPoint: Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
    let symbol: String
}

struct GuideFlow {
    static let cpuInstallPhases = [
        CPUInstallPhase(id: "open", title: "打开扣具", subtitle: "先抬起金属拉杆", symbol: "arrow.up.right"),
        CPUInstallPhase(id: "align", title: "对准三角", subtitle: "CPU 角标对准插槽角标", symbol: "triangle.fill"),
        CPUInstallPhase(id: "place", title: "轻放 CPU", subtitle: "自然落入插槽，不要按压", symbol: "hand.point.down"),
        CPUInstallPhase(id: "lock", title: "压回扣具", subtitle: "扣回拉杆完成固定", symbol: "checkmark")
    ]

    static let memoryInstallPhases = [
        CPUInstallPhase(id: "open", title: "打开卡扣", subtitle: "优先打开 2/4 槽位卡扣", symbol: "arrow.up.left.and.arrow.up.right"),
        CPUInstallPhase(id: "inspect-notch", title: "查看防呆口", subtitle: "先看清内存金手指缺口", symbol: "magnifyingglass"),
        CPUInstallPhase(id: "align-slot", title: "对齐插槽", subtitle: "缺口对准主板插槽凸点", symbol: "rectangle.and.text.magnifyingglass"),
        CPUInstallPhase(id: "install", title: "安装两条内存", subtitle: "两条都对准后垂直压入", symbol: "rectangle.stack.badge.plus"),
        CPUInstallPhase(id: "press-lock", title: "下压回弹", subtitle: "两端下压，卡扣自动回弹", symbol: "checkmark")
    ]

    static let ssdInstallPhases = [
        CPUInstallPhase(id: "remove-heatsink", title: "拆下散热片", subtitle: "先卸下 M.2 散热片和固定螺丝", symbol: "screwdriver"),
        CPUInstallPhase(id: "align-notch", title: "对齐缺口", subtitle: "金手指缺口对准 M.2 插槽", symbol: "rectangle.and.text.magnifyingglass"),
        CPUInstallPhase(id: "insert-angle", title: "斜插 SSD", subtitle: "约 30 度角轻轻插入插槽", symbol: "arrow.down.forward"),
        CPUInstallPhase(id: "press-fix", title: "压平固定", subtitle: "压平尾端后拧紧固定螺丝", symbol: "arrow.down.to.line.compact"),
        CPUInstallPhase(id: "reinstall-heatsink", title: "装回散热片", subtitle: "撕掉导热垫保护膜再装回", symbol: "checkmark")
    ]

    static let componentIntroItems = [
        GuideComponentIntroItem(
            id: "cpu",
            title: "CPU",
            subtitle: "负责运算处理",
            symbol: "cpu",
            imageName: "GuidePartCPU",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "方形芯片，上表面有型号标识，底部有密集触点。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "安装在主板的 CPU 插槽上，并固定散热器。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "gpu",
            title: "显卡",
            subtitle: "负责图形输出",
            symbol: "display",
            imageName: "GuidePartGPU",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "长条板卡，带风扇、金手指和视频输出接口。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "插在主板 PCIe 插槽，并固定在机箱挡板。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "board",
            title: "主板",
            subtitle: "连接所有配件",
            symbol: "rectangle.3.group",
            imageName: "GuidePartBoard",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "大块电路板，上面有 CPU、内存、显卡和硬盘插槽。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "固定在机箱铜柱上，接口朝向机箱背部。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "memory",
            title: "内存",
            subtitle: "临时存储数据",
            symbol: "rectangle.stack",
            imageName: "GuidePartMemory",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "细长条形模块，底部有金手指和防呆缺口。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "插入主板内存插槽，听到卡扣回弹即可。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "ssd",
            title: "SSD",
            subtitle: "存放系统与文件",
            symbol: "externaldrive",
            imageName: "GuidePartSSD",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "小型硬盘模块，常见 M.2 条形或 2.5 英寸方形。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "M.2 SSD 斜插主板插槽后压平固定。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "psu",
            title: "电源",
            subtitle: "为整机供电",
            symbol: "bolt",
            imageName: "GuidePartPSU",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "黑色金属盒，带风扇、电源接口和多组线材。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "固定在机箱电源仓，风扇朝向通风口。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "cooler",
            title: "散热器",
            subtitle: "帮助处理器散热",
            symbol: "fan",
            imageName: "GuidePartCooler",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "由风扇、鳍片和热管组成，底部接触 CPU。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "压在 CPU 上方，风扇线接到 CPU_FAN。", symbol: "mappin.circle")
            ]
        ),
        GuideComponentIntroItem(
            id: "case",
            title: "机箱",
            subtitle: "安装并保护配件",
            symbol: "shippingbox",
            imageName: "GuidePartCase",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "电脑外壳，内部有主板位、电源仓和风扇位。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "所有核心配件最终都会固定在机箱内部。", symbol: "mappin.circle")
            ]
        )
    ]

    static let steps = [
        GuideStepContent(id: "cpu", number: 1, title: "安装 CPU", summary: "将 CPU 放入主板插槽", action: "打开扣具，对准三角标记后轻放 CPU", caution: "不要触碰针脚，不要用力按压", symbol: "cpu"),
        GuideStepContent(id: "memory", number: 2, title: "安装内存", summary: "对准缺口后压入插槽", action: "优先安装 2/4 槽位，双手均匀下压到卡扣回弹", caution: "没有对准缺口时不要强压", symbol: "rectangle.stack"),
        GuideStepContent(id: "ssd", number: 3, title: "安装 SSD", summary: "固定 M.2 固态硬盘", action: "斜插 SSD，压平后用螺丝固定", caution: "散热片胶膜要撕掉", symbol: "externaldrive"),
        GuideStepContent(id: "cooler", number: 4, title: "安装散热器", summary: "涂硅脂并压紧散热器", action: "涂黄豆大小硅脂，对角拧紧散热器", caution: "风扇线要接 CPU_FAN", symbol: "fan"),
        GuideStepContent(id: "board", number: 5, title: "主板入箱", summary: "把主板固定到机箱", action: "确认铜柱位置，对齐背部接口后固定螺丝", caution: "多余铜柱可能造成短路", symbol: "rectangle.3.group"),
        GuideStepContent(id: "psu", number: 6, title: "安装电源", summary: "固定电源并预留线材", action: "确认风扇朝向，固定电源，预留主供电线", caution: "模组线不要混用其他品牌", symbol: "bolt"),
        GuideStepContent(id: "cables", number: 7, title: "接电源线", summary: "连接主板和机箱线", action: "接 24pin、CPU 8pin、前面板和风扇线", caution: "CPU 供电和显卡供电不要插错", symbol: "cable.connector"),
        GuideStepContent(id: "gpu", number: 8, title: "安装显卡", summary: "把显卡插入 PCIe 插槽", action: "打开卡扣，插入显卡，固定挡板螺丝", caution: "显示器线要接到显卡接口", symbol: "display"),
        GuideStepContent(id: "boot", number: 9, title: "首次开机", summary: "检查是否能点亮", action: "接显示器键盘，打开电源，按机箱开机键", caution: "首次开机可能会训练内存较久", symbol: "power"),
        GuideStepContent(id: "finish", number: 10, title: "收尾检查", summary: "检查温度和线材", action: "确认硬件识别、温度正常，再整理线材", caution: "不要带电整理机箱内部线材", symbol: "checkmark.seal")
    ]

    private(set) var isShowingComponentIntro = true
    private(set) var currentIndex = 0

    var currentStep: GuideStepContent {
        Self.steps[currentIndex]
    }

    var canGoPrevious: Bool {
        currentIndex > 0
    }

    var canGoNext: Bool {
        currentIndex < Self.steps.count - 1
    }

    var progressFraction: Double {
        guard Self.steps.count > 1 else { return 1 }
        return Double(currentIndex) / Double(Self.steps.count - 1)
    }

    mutating func startAssembly() {
        isShowingComponentIntro = false
        currentIndex = 0
    }

    mutating func showComponentIntro() {
        isShowingComponentIntro = true
        currentIndex = 0
    }

    mutating func goPrevious() {
        currentIndex = max(currentIndex - 1, 0)
    }

    mutating func goNext() {
        currentIndex = min(currentIndex + 1, Self.steps.count - 1)
    }

    mutating func jump(to index: Int) {
        guard Self.steps.indices.contains(index) else { return }
        currentIndex = index
    }
}
