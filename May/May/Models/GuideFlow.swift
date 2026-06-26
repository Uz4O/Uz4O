import Foundation

struct GuideComponentIntroItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let imageName: String
    let modelName: String?
    let detailPoints: [GuideComponentDetailPoint]

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        imageName: String,
        modelName: String? = nil,
        detailPoints: [GuideComponentDetailPoint]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.imageName = imageName
        self.modelName = modelName
        self.detailPoints = detailPoints
    }
}

struct GuideComponentDetailPoint: Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
    let symbol: String
}

struct GuideSection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let badge: String
    let items: [GuideSectionItem]
}

struct GuideSectionItem: Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
    let symbol: String
}

struct GuideHomeEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let badge: String
}

struct GuideFlow {
    static let guideHomeEntries = [
        GuideHomeEntry(
            id: "troubleshooting",
            title: "点不亮排查助手",
            subtitle: "供电、内存、显卡、灯号逐项排查",
            symbol: "wrench.and.screwdriver",
            badge: "救急"
        ),
        GuideHomeEntry(
            id: "components",
            title: "电脑八大件展示",
            subtitle: "用 3D 模型认识核心配件",
            symbol: "cube.transparent",
            badge: "认识"
        ),
        GuideHomeEntry(
            id: "preparation",
            title: "装机前需准备和了解的事",
            subtitle: "工具、兼容性、顺序先理清",
            symbol: "list.bullet.clipboard",
            badge: "准备"
        ),
        GuideHomeEntry(
            id: "faq",
            title: "常见问题答疑解惑",
            subtitle: "静电、硅脂、风扇、BIOS",
            symbol: "questionmark.bubble",
            badge: "答疑"
        )
    ]

    static var featuredGuideHomeEntry: GuideHomeEntry {
        guideHomeEntries[0]
    }

    static var secondaryGuideHomeEntries: [GuideHomeEntry] {
        Array(guideHomeEntries.dropFirst())
    }

    static let guideSections = [
        GuideSection(
            id: "troubleshooting",
            title: "点不亮排查助手",
            subtitle: "从供电、线材、内存、显卡到主板灯号，一步一步排除。",
            symbol: "wrench.and.screwdriver",
            badge: "救急",
            items: [
                GuideSectionItem(id: "power", title: "先看供电", text: "确认插排有电、电源开关拨到 I、24Pin 主板供电和 CPU 8Pin 都插到底。", symbol: "bolt"),
                GuideSectionItem(id: "memory", title: "只留一根内存", text: "优先插主板说明书推荐的插槽，拔插时听到两侧卡扣回弹。很多点不亮都卡在这里。", symbol: "rectangle.stack"),
                GuideSectionItem(id: "display", title: "显示器线插哪", text: "有独立显卡时，视频线要插显卡接口，不要插主板接口。这个坑非常会装无辜。", symbol: "display"),
                GuideSectionItem(id: "minimal", title: "最小化启动", text: "只保留 CPU、散热器、一根内存、显卡和电源，先让机器成功进 BIOS。", symbol: "checklist")
            ]
        ),
        GuideSection(
            id: "faq",
            title: "常见问题答疑解惑",
            subtitle: "把新手最容易纠结的问题放在一起，先用人话讲清楚。",
            symbol: "questionmark.bubble",
            badge: "答疑",
            items: [
                GuideSectionItem(id: "static", title: "装机会不会被静电打坏？", text: "正常家庭环境概率不高。装机前摸一下机箱金属边框，避免在毛毯上反复摩擦就够用了。", symbol: "hand.raised"),
                GuideSectionItem(id: "paste", title: "硅脂涂多少？", text: "CPU 中间一粒黄豆大小即可。压上散热器后它会自己摊开，不需要涂成壁画。", symbol: "drop"),
                GuideSectionItem(id: "fans", title: "风扇方向怎么看？", text: "多数风扇有支架的一面是出风面。机箱通常前进后出、下进上出。", symbol: "fan"),
                GuideSectionItem(id: "bios", title: "第一次开机要做什么？", text: "能进 BIOS 后先确认 CPU、内存、硬盘都被识别，再考虑开 XMP/EXPO 和装系统。", symbol: "gearshape")
            ]
        ),
        GuideSection(
            id: "preparation",
            title: "装机前需准备和了解的事",
            subtitle: "开工前把工具、空间、说明书和风险点准备好，后面会顺很多。",
            symbol: "list.bullet.clipboard",
            badge: "准备",
            items: [
                GuideSectionItem(id: "tools", title: "准备工具", text: "一把十字螺丝刀、扎带、U 盘系统盘、干净桌面，以及一个放小螺丝的小盒子。", symbol: "screwdriver"),
                GuideSectionItem(id: "manual", title: "先看主板说明书", text: "内存推荐插槽、前面板针脚、M.2 螺丝位置都在里面。说明书是新手的隐藏队友。", symbol: "book"),
                GuideSectionItem(id: "compatibility", title: "确认兼容性", text: "检查主板尺寸、CPU 插槽、内存代数、散热器限高、显卡长度和电源功率。", symbol: "checkmark.seal"),
                GuideSectionItem(id: "order", title: "推荐顺序", text: "桌面上先装 CPU、内存、SSD 和散热器底座，再把主板放进机箱，最后接线。", symbol: "arrow.down.doc")
            ]
        )
    ]

    static let componentIntroItems = [
        GuideComponentIntroItem(
            id: "cpu",
            title: "CPU",
            subtitle: "负责运算处理",
            symbol: "cpu",
            imageName: "GuidePartCPU",
            modelName: "desktop-cpu-mobile",
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
            modelName: "dual-fan-gpu-mobile",
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
            modelName: "modern-atx-motherboard-mobile",
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
            modelName: "desktop-dimm-ram-mobile",
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
            modelName: "m2-2280-nvme-ssd-mobile",
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
            modelName: "atx-psu-mobile",
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
            modelName: "tower-cpu-air-cooler-mobile",
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
}
