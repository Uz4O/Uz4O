import SwiftUI

struct BootTroubleshootingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var session = BootTroubleshootingSession()
    @State private var selectedAnswerID: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                phaseContent
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
            .id(session.stage)
        }
        .background(Color.white.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActions
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: session.stage)
    }

    private var header: some View {
        ZStack {
            Text(headerTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            HStack {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.white, in: Circle())
                        .micro3DSurface(
                            cornerRadius: 22,
                            rimColor: Color.black.opacity(0.035),
                            borderColor: Color.white,
                            shadowColor: Color.black.opacity(0.07)
                        )
                }
                .buttonStyle(Micro3DPressButtonStyle())
                .accessibilityLabel(session.stage == .symptoms ? "关闭" : "返回")

                Spacer()

                if session.stage != .symptoms {
                    Button("重置") {
                        withAnimation { restart() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .frame(height: 58)
        .background(Color.white)
    }

    private var headerTitle: String {
        switch session.stage {
        case .symptoms, .question:
            "开机故障排查"
        case .action:
            "优先检查"
        case .resolved, .unresolved:
            "排查结果"
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch session.stage {
        case .symptoms:
            symptomSelection
                .transition(.opacity)
        case .question:
            questionStep
                .transition(.opacity)
        case .action:
            actionStep
                .transition(.opacity)
        case .resolved:
            resolvedResult
                .transition(.opacity)
        case .unresolved:
            unresolvedResult
                .transition(.opacity)
        }
    }

    private var symptomSelection: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("电脑现在是什么情况？")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)

                Text("选择最接近的现象，我们按顺序检查")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            symptomGroup(
                title: "开机时",
                scenarios: BootTroubleshootingCatalog.scenarios.prefix(4)
            )
            symptomGroup(
                title: "进入 BIOS 后",
                scenarios: BootTroubleshootingCatalog.scenarios.dropFirst(4)
            )
        }
    }

    private func symptomGroup(
        title: String,
        scenarios: ArraySlice<BootTroubleshootingScenario>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            VStack(spacing: 0) {
                ForEach(scenarios) { scenario in
                    symptomRow(scenario)

                    if scenario.id != scenarios.last?.id {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 10, y: 4)
        }
    }

    private func symptomRow(_ scenario: BootTroubleshootingScenario) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                session.selectScenario(scenario.id)
                session.beginQuestions()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: scenario.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.softSurface, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(scenario.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(scenario.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scenario.title)，\(scenario.subtitle)")
    }

    @ViewBuilder
    private var questionStep: some View {
        if let scenario = session.selectedScenario {
            VStack(alignment: .leading, spacing: 20) {
                stageProgress(label: "第 1 / 2 阶段", progress: 0.5)

                VStack(alignment: .leading, spacing: 7) {
                    Text(scenario.question)
                        .font(.system(size: 29, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(scenario.questionHint)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                questionIllustration(for: scenario)

                VStack(spacing: 12) {
                    ForEach(scenario.choices) { choice in
                        questionChoice(choice)
                    }
                }
            }
        }
    }

    private func questionChoice(_ choice: BootTroubleshootingChoice) -> some View {
        let isSelected = selectedAnswerID == choice.id
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedAnswerID = choice.id
            }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.white : AppTheme.mutedText.opacity(0.62), lineWidth: 2)
                        .frame(width: 21, height: 21)
                    if isSelected {
                        Circle().fill(Color.white).frame(width: 9, height: 9)
                    }
                }
                Text(choice.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? Color.black : Color.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.black : AppTheme.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.055), radius: 10, y: 5)
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    @ViewBuilder
    private func questionIllustration(for scenario: BootTroubleshootingScenario) -> some View {
        if scenario.id == "no-display" {
            Image("BootGuideVideoPorts")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26))
        } else if scenario.id == "debug-light" {
            DebugLightDiagram()
                .frame(maxWidth: .infinity)
                .frame(height: 154)
                .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26))
        } else {
            Image(systemName: scenario.symbol)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26))
        }
    }

    @ViewBuilder
    private var actionStep: some View {
        if let outcome = session.outcome, let step = session.currentStep {
            VStack(alignment: .leading, spacing: 16) {
                outcomeSummary(outcome)

                stageProgress(
                    label: "第 \(session.currentStepIndex + 1) 步，共 \(outcome.steps.count) 步",
                    progress: session.progress
                )

                VStack(alignment: .leading, spacing: 15) {
                    Text("按图完成这一步")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)

                    HStack(alignment: .top, spacing: 12) {
                        Text(String(format: "%02d", session.currentStepIndex + 1))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.black, in: Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(step.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let assetName = actionImageAssetName(for: step.id) {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else if step.id == "gpu-video-port" {
                        VideoPortActionDiagram()
                    } else {
                        Image(systemName: step.symbol)
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 124)
                            .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(18)
                .micro3DSurface(cornerRadius: 24, showsTopHighlight: false)

                if let warning = step.warning {
                    safetyBanner(warning, isCritical: false)
                } else {
                    safetyBanner("进行插拔或拆装前，请先关机、拔掉电源线并完成放电。", isCritical: false)
                }
            }
        }
    }

    private func actionImageAssetName(for stepID: String) -> String? {
        switch stepID {
        case "gpu-video-port", "display-source-cable", "vga-output":
            "BootGuideVideoPorts"
        case "psu-switch", "pulse-discharge":
            "BootGuidePowerSwitch"
        case "board-power", "pulse-power", "restart-power", "cpu-eps":
            "BootGuideMotherboardPower"
        case "pulse-memory", "display-memory", "restart-memory", "dram-a2", "dram-sticks":
            "BootGuideMemory"
        default:
            nil
        }
    }

    private func outcomeSummary(_ outcome: BootTroubleshootingOutcome) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(Color.white, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("本次排查方向")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(outcome.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("预计检查时间 \(outcome.estimatedMinutes) 分钟")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(outcome.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.top, 3)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.border.opacity(0.7), lineWidth: 1)
        }
    }

    private var resolvedResult: some View {
        VStack(alignment: .leading, spacing: 18) {
            resultHero(
                symbol: "checkmark",
                color: AppTheme.success,
                title: "问题已解决",
                detail: "已记录本次完成的检查项目。"
            )

            if let outcome = session.outcome {
                resultSummaryCard(
                    title: "本次排查方向",
                    detail: outcome.title,
                    rows: ["完成 \(session.completedStepIDs.count) 项检查"]
                )
            }

            Text("如果问题再次出现，可以从同一症状重新排查；反复出现通常值得让售后做稳定性检测。")
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(4)
        }
    }

    private var unresolvedResult: some View {
        VStack(alignment: .leading, spacing: 18) {
            resultHero(
                symbol: "exclamationmark",
                color: AppTheme.warning,
                title: "暂时没有排除故障",
                detail: "继续拆装的风险已经高于收益，建议带着检查记录送修。"
            )

            if let outcome = session.outcome {
                let completed = outcome.steps.filter { session.completedStepIDs.contains($0.id) }
                resultSummaryCard(
                    title: "已经检查",
                    detail: outcome.summary,
                    rows: completed.map(\.title)
                )
            }

            safetyBanner(BootTroubleshootingCatalog.safetyNotice, isCritical: true)
        }
    }

    private func resultHero(symbol: String, color: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(color, in: Circle())

            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(AppTheme.primaryText)
            Text(detail)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(4)
        }
        .padding(.vertical, 12)
    }

    private func resultSummaryCard(title: String, detail: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(AppTheme.primaryText)
            Text(detail)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(4)

            ForEach(rows, id: \.self) { row in
                Label(row, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micro3DSurface(cornerRadius: 22, showsTopHighlight: false)
    }

    private func stageProgress(label: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.mutedText)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(Color.black)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 5)
        }
    }

    private func safetyBanner(_ text: String, isCritical: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isCritical ? "exclamationmark.triangle.fill" : "exclamationmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(isCritical ? AppTheme.error : AppTheme.warning, in: Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.47, green: 0.31, blue: 0.08))
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(red: 1.0, green: 0.97, blue: 0.90), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.warning.opacity(0.24), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        if session.stage != .symptoms {
            VStack(spacing: 0) {
                Divider().opacity(0.45)

                switch session.stage {
                case .symptoms:
                    EmptyView()
                case .question:
                    primaryBottomButton(title: "继续", icon: "arrow.right", isEnabled: selectedAnswerID != nil) {
                        guard let selectedAnswerID else { return }
                        withAnimation { session.selectChoice(selectedAnswerID) }
                    }
                case .action:
                    HStack(spacing: 10) {
                        bottomButton(title: actionIncompleteTitle, isPrimary: false) {
                            withAnimation { session.continueUnresolved() }
                        }
                        bottomButton(title: actionCompleteTitle, isPrimary: true) {
                            withAnimation { session.markResolved() }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                case .resolved, .unresolved:
                    HStack(spacing: 10) {
                        bottomButton(title: "重新排查", isPrimary: false) {
                            withAnimation { restart() }
                        }
                        bottomButton(title: "结束", isPrimary: true) {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
    }

    private func primaryBottomButton(
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: icon)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: 520)
            .frame(height: 54)
            .background(isEnabled ? Color.black : Color.black.opacity(0.2), in: Capsule())
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func bottomButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isPrimary ? Color.white : AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isPrimary ? Color.black : Color.white, in: Capsule())
                .overlay {
                    if !isPrimary {
                        Capsule().stroke(AppTheme.border, lineWidth: 1.2)
                    }
                }
        }
        .buttonStyle(Micro3DPressButtonStyle())
    }

    private func handleBack() {
        if session.stage == .symptoms {
            dismiss()
        } else {
            if session.stage == .question || session.stage == .action {
                selectedAnswerID = nil
            }
            withAnimation { session.goBack() }
        }
    }

    private func restart() {
        selectedAnswerID = nil
        session.restart()
    }

    private var actionCompleteTitle: String {
        session.selectedScenarioID == "no-display" ? "现在有画面了" : "问题解决了"
    }

    private var actionIncompleteTitle: String {
        session.selectedScenarioID == "no-display" ? "做完了，但还是没有画面" : "做完了，但问题还在"
    }
}

private struct VideoConnectionDiagram: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.9))
                .frame(width: 180, height: 170)

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.68)).frame(width: 30, height: 13)
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.68)).frame(width: 30, height: 13)
                    Circle().fill(Color.white.opacity(0.25)).frame(width: 21, height: 21)
                }
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.black).frame(width: 42, height: 15)
                    RoundedRectangle(cornerRadius: 4).fill(Color.black).frame(width: 42, height: 15)
                    Circle().fill(Color(red: 0.24, green: 0.64, blue: 0.43)).frame(width: 13, height: 13)
                }
                .padding(13)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            }

            Text("主板接口")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.warning)
                .offset(x: -122, y: -45)
            Text("显卡接口")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .offset(x: 116, y: 67)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("机箱背面接口示意，主板接口在上方，独立显卡接口在下方")
    }
}

private struct DebugLightDiagram: View {
    private let labels = ["CPU", "DRAM", "VGA", "BOOT"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(labels, id: \.self) { label in
                VStack(spacing: 10) {
                    Circle()
                        .fill(label == "DRAM" ? AppTheme.warning : Color.black.opacity(0.12))
                        .frame(width: 18, height: 18)
                        .shadow(color: label == "DRAM" ? AppTheme.warning.opacity(0.5) : .clear, radius: 7)
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("主板 CPU、DRAM、VGA、BOOT 故障灯示意")
    }
}

private struct VideoPortActionDiagram: View {
    var body: some View {
        HStack(spacing: 12) {
            portCard(title: "不要接这里", color: AppTheme.warning, isCorrect: false)
            portCard(title: "接到显卡", color: Color(red: 0.24, green: 0.64, blue: 0.43), isCorrect: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("视频线连接示意，应连接独立显卡接口，不要连接主板接口")
    }

    private func portCard(title: String, color: Color, isCorrect: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: isCorrect ? .bottom : .top) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.9))
                    .frame(width: 76, height: 98)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(isCorrect ? 1 : 0.12))
                    .frame(width: 52, height: 23)
                    .padding(.vertical, 13)
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .offset(y: isCorrect ? 12 : -12)
            }
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        BootTroubleshootingView()
    }
}
