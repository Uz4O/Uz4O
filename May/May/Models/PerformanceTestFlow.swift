import Foundation

enum PerformanceTestStep: Int, CaseIterable {
    case hardware
    case conditions
    case result

    var title: String {
        switch self {
        case .hardware:
            return "电脑配置"
        case .conditions:
            return "测试条件"
        case .result:
            return "性能结果"
        }
    }
}

enum PerformanceResolution: String, CaseIterable, Identifiable {
    case fullHD
    case twoK
    case fourK

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD:
            return "1080P"
        case .twoK:
            return "2K"
        case .fourK:
            return "4K"
        }
    }

    var subtitle: String {
        switch self {
        case .fullHD:
            return "主流高刷显示器"
        case .twoK:
            return "画质和帧率平衡"
        case .fourK:
            return "更吃显卡性能"
        }
    }
}

struct PerformanceGame: Equatable, Identifiable {
    let id: String
    let name: String
    let mark: String

    static let cyberpunk = PerformanceGame(id: "cyberpunk", name: "赛博朋克 2077", mark: "2077")
    static let valorant = PerformanceGame(id: "valorant", name: "无畏契约", mark: "V")

    static let samples = [
        cyberpunk,
        PerformanceGame(id: "cs2", name: "CS2", mark: "CS"),
        PerformanceGame(id: "pubg", name: "PUBG", mark: "PUBG"),
        PerformanceGame(id: "lol", name: "英雄联盟", mark: "LOL"),
        PerformanceGame(id: "elden-ring", name: "艾尔登法环", mark: "环"),
        PerformanceGame(id: "genshin", name: "原神", mark: "原"),
        PerformanceGame(id: "apex", name: "APEX 英雄", mark: "A"),
        valorant,
        PerformanceGame(id: "cod", name: "使命召唤", mark: "COD")
    ]
}

struct PerformanceTestResult: Equatable {
    let resolution: String
    let primaryGame: String
    let averageFPS: String
    let lowFPS: String
    let bottleneck: String
    let advice: String
}

struct PerformanceTestFlow: Equatable {
    var currentStep: PerformanceTestStep = .hardware
    var hardwareProfile: HardwareProfile = HardwareProfile(
        cpu: "i5-14600K",
        gpu: "RTX 4070",
        motherboard: "B760M AORUS ELITE GEN5",
        memory: "16GB",
        storage: "Western Digital WD Black SN850X · 1TB · PCIe 4.0",
        powerSupply: "Corsair RM750e · 750W · 80+ Gold"
    )
    var selectedResolution: PerformanceResolution = .twoK
    var selectedGames: [PerformanceGame] = [.cyberpunk]

    var result: PerformanceTestResult {
        let baseFPS: Int
        switch selectedResolution {
        case .fullHD:
            baseFPS = 142
        case .twoK:
            baseFPS = 118
        case .fourK:
            baseFPS = 72
        }

        let bottleneck = selectedResolution == .fourK ? "显卡" : "显卡余量"
        let primaryGame = selectedGames.first?.name ?? "未选择游戏"

        return PerformanceTestResult(
            resolution: selectedResolution.title,
            primaryGame: primaryGame,
            averageFPS: "\(baseFPS) FPS",
            lowFPS: "\(max(baseFPS - 28, 45)) FPS",
            bottleneck: bottleneck,
            advice: selectedResolution == .fourK
                ? "4K 下主要压力在显卡，想提升体验优先看显卡和电源余量。"
                : "当前配置更适合 \(selectedResolution.title) 游戏，优先保证显卡驱动和内存容量。"
        )
    }

    mutating func goNext() {
        guard let next = PerformanceTestStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    mutating func goPrevious() {
        guard let previous = PerformanceTestStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    mutating func toggleGame(_ game: PerformanceGame) {
        if selectedGames.contains(game) {
            if selectedGames.count > 1 {
                selectedGames.removeAll { $0 == game }
            }
        } else {
            selectedGames.append(game)
        }
    }
}
