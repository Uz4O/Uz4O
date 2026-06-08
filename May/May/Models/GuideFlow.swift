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

struct GuideFlow {
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
