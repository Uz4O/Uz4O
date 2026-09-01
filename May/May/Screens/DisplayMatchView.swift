import SwiftUI

struct DisplayMatchView: View {
    let savedHardwareProfile: HardwareProfile
    let onBack: () -> Void

    @State private var gpu: String
    @State private var cpu: String
    @State private var selectedGames: Set<String> = ["cyberpunk-2077"]
    @State private var hardwareCategory: HardwareOptionCategory?
    @State private var result: DisplayMatchResponseDTO?
    @State private var showsRecommendation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var requestTask: Task<Void, Never>?

    init(savedHardwareProfile: HardwareProfile, onBack: @escaping () -> Void) {
        self.savedHardwareProfile = savedHardwareProfile
        self.onBack = onBack
        _gpu = State(initialValue: HardwareCatalog.gpus.contains { $0.name == savedHardwareProfile.gpu } ? savedHardwareProfile.gpu : "不知道")
        _cpu = State(initialValue: HardwareCatalog.cpus.contains { $0.name == savedHardwareProfile.cpu } ? savedHardwareProfile.cpu : "不知道")
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hardwareSection
                        gamesSection
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle")
                                .font(.appBody)
                                .foregroundStyle(AppTheme.error)
                        }
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }

            if showsRecommendation, let result {
                recommendationOverlay(result)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionButton }
        .sheet(item: $hardwareCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: HardwareCatalog.filters(for: category.title),
                contextMessage: category.title == "CPU" ? "高刷电竞游戏很依赖 CPU 单核性能" : "显卡性能决定显示器分辨率和高刷上限",
                selectedValue: category.title == "CPU" ? $cpu : $gpu
            )
            .presentationDetents([.large])
        }
        .onChange(of: gpu) { _, _ in clearResult() }
        .onChange(of: cpu) { _, _ in clearResult() }
        .onChange(of: selectedGames) { _, _ in clearResult() }
        .onDisappear { requestTask?.cancel() }
        .alert("推荐失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var header: some View {
        ZStack {
            Text("选显示器").font(.appHeadline).foregroundStyle(AppTheme.primaryText)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.primaryText).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(height: 52)
    }

    private var hardwareSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("测试配置").font(.appHeadline).foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("仅需 CPU 和显卡").font(.appCaption).foregroundStyle(AppTheme.secondaryText)
            }
            HStack(spacing: 0) {
                hardwareButton(title: "CPU", icon: "cpu", value: cpu)
                Divider().frame(height: 44)
                hardwareButton(title: "显卡", icon: "display", value: gpu)
            }
            .micro3DSurface(cornerRadius: 16, showsTopHighlight: false)
        }
    }

    private func hardwareButton(title: String, icon: String, value: String) -> some View {
        Button {
            hardwareCategory = HardwareProfileOptions.categories.first { $0.title == title }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .micro3DSurface(cornerRadius: 13, surfaceColor: AppTheme.softSurface, showsTopHighlight: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.appSubheadline).foregroundStyle(AppTheme.primaryText)
                        Text(value == "不知道" ? "未选择" : value)
                            .font(.appBody)
                            .foregroundStyle(value == "不知道" ? AppTheme.secondaryText : AppTheme.primaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text("选择游戏").font(.appHeadline).foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("已选择 \(selectedGames.count) 款").font(.appCaption).foregroundStyle(AppTheme.secondaryText)
                Button(selectedGames.count == PerformanceGame.samples.count ? "清空" : "全选") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        if selectedGames.count == PerformanceGame.samples.count {
                            selectedGames.removeAll()
                        } else {
                            selectedGames = Set(PerformanceGame.samples.map(\.id))
                        }
                    }
                }
                .font(.appBody.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            displayGameList
        }
    }

    private var displayGameList: some View {
        VStack(spacing: 0) {
            ForEach(Array(PerformanceGame.samples.enumerated()), id: \.element.id) { index, game in
                let selected = selectedGames.contains(game.id)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        if selected { selectedGames.remove(game.id) } else { selectedGames.insert(game.id) }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(game.displayArtworkAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .micro3DSurface(
                                cornerRadius: 13,
                                rimColor: AppTheme.border.opacity(0.78),
                                borderColor: Color.white.opacity(0.92),
                                shadowColor: Color.black.opacity(0.11),
                                showsTopHighlight: false
                            )

                        Text(game.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.border)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 76)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(selected ? "已选择" : "未选择")

                if index != PerformanceGame.samples.count - 1 {
                    Divider().padding(.leading, 86)
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.border.opacity(0.75), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.075), radius: 9, x: 0, y: 5)
    }

    private var actionButton: some View {
        Button(action: startMatch) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) }
                Text(isLoading ? "正在生成建议…" : (result == nil ? "推荐显示器规格" : "重新推荐")).font(.system(size: 16, weight: .bold))
                if !isLoading { Image(systemName: "arrow.right") }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 520)
            .frame(height: 52)
            .background(Color.black, in: Capsule())
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .disabled(isLoading)
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
    }

    private func recommendationOverlay(_ result: DisplayMatchResponseDTO) -> some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("推荐规格").font(.system(size: 22, weight: .bold)).foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Button { withAnimation { showsRecommendation = false } } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.primaryText).frame(width: 36, height: 36).background(AppTheme.softSurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Text(result.summary).font(.appBody).foregroundStyle(AppTheme.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    spec("分辨率", result.resolution.uppercased())
                    spec("刷新率", "\(result.refreshRate)Hz")
                    spec("尺寸", result.size)
                    spec("同步", "Adaptive-Sync")
                }
                ForEach(result.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.circle.fill").font(.appCaption).foregroundStyle(AppTheme.primaryText)
                }
                Button { withAnimation { showsRecommendation = false } } label: {
                    Text("知道了").font(.appSubheadline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48).background(AppTheme.primaryButton, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 28, y: 12)
            .padding(24)
        }
        .onTapGesture { }
    }

    private func spec(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .regular)).foregroundStyle(AppTheme.secondaryText)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppTheme.primaryText).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 13))
    }

    private func startMatch() {
        guard let cpuID = HardwareCatalog.cpus.first(where: { $0.name == cpu })?.id,
              let gpuID = HardwareCatalog.gpus.first(where: { $0.name == gpu })?.id,
              !selectedGames.isEmpty else {
            errorMessage = "请先选择显卡和至少一款游戏。"
            return
        }
        requestTask?.cancel()
        isLoading = true
        errorMessage = nil
        requestTask = Task {
            do {
                result = try await AppAPIClient().displayMatch(
                    cpuID: cpuID,
                    gpuID: gpuID,
                    gameIDs: PerformanceGame.samples.filter { selectedGames.contains($0.id) }.map(\.id)
                )
                withAnimation { showsRecommendation = true }
            } catch is CancellationError {
                return
            } catch {
                result = nil
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func clearResult() {
        requestTask?.cancel()
        requestTask = nil
        result = nil
        errorMessage = nil
        isLoading = false
        showsRecommendation = false
    }
}

private extension PerformanceGame {
    var displayArtworkAssetName: String {
        switch id {
        case "valorant": "GameArtworkValorant"
        case "cs2": "GameArtworkCS2"
        case "pubg": "GameArtworkPUBG"
        case "delta-force": "GameArtworkDeltaForce"
        case "teamfight-tactics": "GameArtworkTeamfightTactics"
        case "league-of-legends": "GameArtworkLeagueOfLegends"
        case "call-of-duty-warzone": "GameArtworkCallOfDuty"
        case "cyberpunk-2077": "GameArtworkCyberpunk2077"
        case "red-dead-redemption-2": "GameArtworkRedDeadRedemption2"
        case "gta-v": "GameArtworkGTAV"
        case "black-myth-wukong": "GameArtworkBlackMythWukong"
        case "forza-horizon-6": "GameArtworkForzaHorizon6"
        case "elden-ring": "GameArtworkEldenRing"
        case "cities-skylines": "GameArtworkCitiesSkylines"
        case "minecraft-java-edition": "GameArtworkMinecraft"
        default: "GameArtworkValorant"
        }
    }
}

#Preview {
    DisplayMatchView(savedHardwareProfile: .skipped, onBack: {})
}
