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
    static let componentIntroItems = [
        GuideComponentIntroItem(
            id: "cpu",
            title: "CPU",
            subtitle: "负责运算处理",
            symbol: "cpu",
            imageName: "GuidePartCPU",
            detailPoints: [
                GuideComponentDetailPoint(id: "appearance", title: "外观识别", text: "方形芯片，上表面有型号标识，底部有密集触点。", symbol: "magnifyingglass"),
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "执行计算和指令，是电脑的大脑。", symbol: "waveform.path.ecg"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "负责游戏、渲染和显示器画面输出。", symbol: "sparkles"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "让所有配件互相通信，并提供供电接口。", symbol: "point.3.connected.trianglepath.dotted"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "临时存放正在运行的程序和数据。", symbol: "arrow.left.arrow.right"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "保存系统、软件、游戏和个人文件。", symbol: "folder"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "把墙插电力转换成各配件需要的稳定供电。", symbol: "bolt.fill"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "把 CPU 热量带走，避免降频或过热关机。", symbol: "thermometer.medium"),
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
                GuideComponentDetailPoint(id: "role", title: "主要作用", text: "保护配件、组织线材，并建立风道。", symbol: "wind"),
                GuideComponentDetailPoint(id: "install", title: "安装位置", text: "所有核心配件最终都会固定在机箱内部。", symbol: "mappin.circle")
            ]
        )
    ]

    static let steps = [
        GuideStepContent(id: "prepare", number: 1, title: "检查准备", summary: "先确认工具和零件", action: "清点零件，整理桌面，阅读主板说明书", caution: "不要接通电源，避免静电环境", symbol: "checklist"),
        GuideStepContent(id: "cpu", number: 2, title: "安装 CPU", summary: "将 CPU 放入主板插槽", action: "打开扣具，对准三角标记后轻放 CPU", caution: "不要触碰针脚，不要用力按压", symbol: "cpu"),
        GuideStepContent(id: "memory", number: 3, title: "安装内存", summary: "对准缺口后压入插槽", action: "打开卡扣，双手均匀下压到卡扣回弹", caution: "没有对准缺口时不要强压", symbol: "rectangle.stack"),
        GuideStepContent(id: "ssd", number: 4, title: "安装 SSD", summary: "固定 M.2 固态硬盘", action: "斜插 SSD，压平后用螺丝固定", caution: "散热片胶膜要撕掉", symbol: "externaldrive"),
        GuideStepContent(id: "cooler", number: 5, title: "安装散热器", summary: "涂硅脂并压紧散热器", action: "涂黄豆大小硅脂，对角拧紧散热器", caution: "风扇线要接 CPU_FAN", symbol: "fan"),
        GuideStepContent(id: "board", number: 6, title: "主板入箱", summary: "把主板固定到机箱", action: "确认铜柱位置，对齐背部接口后固定螺丝", caution: "多余铜柱可能造成短路", symbol: "rectangle.3.group"),
        GuideStepContent(id: "psu", number: 7, title: "安装电源", summary: "固定电源并预留线材", action: "确认风扇朝向，固定电源，预留主供电线", caution: "模组线不要混用其他品牌", symbol: "bolt"),
        GuideStepContent(id: "cables", number: 8, title: "接电源线", summary: "连接主板和机箱线", action: "接 24pin、CPU 8pin、前面板和风扇线", caution: "CPU 供电和显卡供电不要插错", symbol: "cable.connector"),
        GuideStepContent(id: "gpu", number: 9, title: "安装显卡", summary: "把显卡插入 PCIe 插槽", action: "打开卡扣，插入显卡，固定挡板螺丝", caution: "显示器线要接到显卡接口", symbol: "display"),
        GuideStepContent(id: "boot", number: 10, title: "首次开机", summary: "检查是否能点亮", action: "接显示器键盘，打开电源，按机箱开机键", caution: "首次开机可能会训练内存较久", symbol: "power"),
        GuideStepContent(id: "finish", number: 11, title: "收尾检查", summary: "检查温度和线材", action: "确认硬件识别、温度正常，再整理线材", caution: "不要带电整理机箱内部线材", symbol: "checkmark.seal")
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
