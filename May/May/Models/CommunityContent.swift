import Foundation

struct CommunityTopic: Equatable, Identifiable {
    var id: String { title }

    let title: String

    static let defaultTopics = [
        CommunityTopic(title: "推荐"),
        CommunityTopic(title: "最新"),
        CommunityTopic(title: "关注"),
        CommunityTopic(title: "装机配置"),
        CommunityTopic(title: "硬件评测"),
        CommunityTopic(title: "求助问答"),
        CommunityTopic(title: "交流分享")
    ]
}

struct CommunityAuthor: Equatable {
    let name: String
    let subtitle: String
    let avatarInitial: String
}

struct CommunityStats: Equatable {
    let likes: Int
    let comments: Int
    let saves: Int
}

struct CommunityPost: Equatable, Identifiable {
    let id: String
    let author: CommunityAuthor
    let title: String
    let summary: String
    let body: String
    let createdAt: String
    let tags: [String]
    let parts: [String]
    let stats: CommunityStats
    let isPinned: Bool

    static let featuredFeed = [
        CommunityPost(
            id: "value-build-may",
            author: CommunityAuthor(name: "装机达人小明", subtitle: "30 分钟前", avatarInitial: "明"),
            title: "2024 年 5 月高性价比装机配置推荐",
            summary: "分享一套 5000 元左右的高性价比配置，适合游戏和生产力需求。",
            body: "这套配置把预算优先放在显卡和稳定电源上，CPU 选择够用不浪费的 i5 档位，适合 2K 游戏、日常剪辑和长期升级。",
            createdAt: "30 分钟前",
            tags: ["装机配置", "性价比", "游戏主机"],
            parts: [
                "CPU：Intel Core i5-14600K",
                "主板：ROG STRIX Z790-A",
                "内存：Corsair DDR5 32GB 6000MHz",
                "显卡：NVIDIA RTX 4070 Ti",
                "电源：Seasonic 850W",
                "散热：NZXT Kraken 360"
            ],
            stats: CommunityStats(likes: 128, comments: 256, saves: 1024),
            isPinned: true
        ),
        CommunityPost(
            id: "i5-vs-7800x3d",
            author: CommunityAuthor(name: "硬核玩家阿杰", subtitle: "1 小时前", avatarInitial: "杰"),
            title: "i5-14600K vs R7 7800X3D 怎么选？",
            summary: "最近在纠结这两颗 CPU，主要用途是游戏，求大佬给点建议。",
            body: "预算够但不想乱花钱，显示器是 2K 165Hz。希望游戏帧率稳，也希望平时开浏览器和语音时别卡。",
            createdAt: "1 小时前",
            tags: ["硬件评测", "CPU", "求助问答"],
            parts: [
                "候选：Intel Core i5-14600K",
                "候选：AMD Ryzen 7 7800X3D",
                "显卡：RTX 4070 Super",
                "显示器：2K 165Hz"
            ],
            stats: CommunityStats(likes: 86, comments: 194, saves: 512),
            isPinned: false
        ),
        CommunityPost(
            id: "water-vs-air-cooling",
            author: CommunityAuthor(name: "散热研究所", subtitle: "2 小时前", avatarInitial: "散"),
            title: "360 水冷 vs 风冷，散热效果差距有多大？",
            summary: "实测对比了多款 360 水冷和风冷散热器，数据说话。",
            body: "如果不追求极限超频，高规格风冷已经能覆盖很多日常场景。360 水冷更适合高功耗 CPU、海景房外观和低温展示需求。",
            createdAt: "2 小时前",
            tags: ["硬件评测", "散热", "交流分享"],
            parts: [
                "测试平台：i7-14700K",
                "机箱：ATX 风道机箱",
                "对比：360 水冷 / 双塔风冷",
                "结论：日常差距小，满载差距明显"
            ],
            stats: CommunityStats(likes: 64, comments: 128, saves: 256),
            isPinned: false
        )
    ]
}

struct CommunityComposerDraft: Equatable {
    static let characterLimit = 1000

    var text = ""
    private(set) var selectedTopicTitles: [String] = ["装机配置"]

    mutating func toggleTopic(_ title: String) {
        if let index = selectedTopicTitles.firstIndex(of: title) {
            selectedTopicTitles.remove(at: index)
        } else {
            selectedTopicTitles.append(title)
        }
    }
}
