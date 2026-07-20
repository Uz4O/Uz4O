import SwiftUI

struct BuildResultView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false

    let plan: BuildPlan
    let onBack: () -> Void

    private var isVisible: Bool {
        hasRevealed || reduceMotion
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 11) {
                resultHeader
                    .padding(.bottom, 7)

                Text(AIContentDisclosure.text)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.40, green: 0.44, blue: 0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 5)
                    .padding(.bottom, 2)

                PerformanceCard()
                BuildSummaryCard(plan: plan)
                PartsListCard(plan: plan, isVisible: isVisible, hasRevealed: hasRevealed)

                Text("价格可能随市场波动，请以实际购买时为准。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.42, green: 0.46, blue: 0.54))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 1)

                PrimaryButton(title: "保存配置单", icon: "tray.and.arrow.down", action: {}, backgroundColor: .black)
                .padding(.top, 1)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 15)
            .padding(.top, 13)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.28), value: hasRevealed)
        }
        .background(Color(red: 0.985, green: 0.985, blue: 0.985).ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            hasRevealed = true
        }
    }

    private var resultHeader: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Text("配置方案详情")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)

            Spacer()
        }
    }
}

private struct PerformanceCard: View {
    var body: some View {
        ResultCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 6) {
                    Text("游戏性能表现")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.black)

                HStack(spacing: 0) {
                    PerformanceGauge()
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(ResultColors.divider)
                        .frame(width: 1, height: 56)

                    PerformanceMetric(title: "1080P 电竞", value: "240")
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(ResultColors.divider)
                        .frame(width: 1, height: 56)

                    PerformanceMetric(title: "4K 高画质", value: "96")
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 105)
            }
        }
    }
}

private struct PerformanceGauge: View {
    var body: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { index in
                Capsule()
                    .fill(ResultColors.gaugeTick)
                    .frame(width: 1, height: index < 13 ? 0 : 6)
                    .offset(y: -48)
                    .rotationEffect(.degrees(Double(index) * 7.5))
            }

            Circle()
                .stroke(ResultColors.gaugeTrack, lineWidth: 1)
                .frame(width: 84, height: 84)

            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 84, height: 84)

            VStack(spacing: -1) {
                Text("168")
                    .font(.system(size: 30, weight: .medium))
                Text("FPS")
                    .font(.system(size: 11))
                Text("2K 3A 大作")
                    .font(.system(size: 10))
                    .padding(.top, 5)
            }
            .foregroundStyle(.black)
        }
        .frame(width: 108, height: 108)
    }
}

private struct PerformanceMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 25, weight: .medium))
            Text("FPS")
                .font(.system(size: 11))
        }
        .foregroundStyle(.black)
    }
}

private struct BuildSummaryCard: View {
    let plan: BuildPlan

    var body: some View {
        ResultCard(verticalPadding: 14, horizontalPadding: 15) {
            HStack(spacing: 10) {
                SummaryMetric(icon: "yensign", title: "配置总价", value: compactPrice)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(ResultColors.divider)
                    .frame(width: 1, height: 31)

                SummaryMetric(icon: "waveform.path.ecg", title: "预计功耗", value: powerText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(ResultColors.divider)
                    .frame(width: 1, height: 31)

                SummaryMetric(icon: "gamecontroller", title: "适合场景", value: plan.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var compactPrice: String {
        plan.totalPrice.replacingOccurrences(of: "¥ ", with: "¥")
    }

    private var powerText: String {
        guard let powerSupply = plan.parts.first(where: { $0.category == "电源" }),
              let range = powerSupply.model.range(of: #"\b\d{3,4}W\b"#, options: .regularExpression)
        else { return "—" }
        return String(powerSupply.model[range])
    }
}

private struct SummaryMetric: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(icon == "yensign" ? Color.black : .clear, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(ResultColors.secondaryText)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }
}

private struct PartsListCard: View {
    let plan: BuildPlan
    let isVisible: Bool
    let hasRevealed: Bool

    var body: some View {
        ResultCard(verticalPadding: 16, horizontalPadding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("配件清单")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.bottom, 9)

                ForEach(Array(plan.parts.enumerated()), id: \.element.id) { index, part in
                    ResultPartRow(part: part)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 10)
                        .animation(
                            .easeOut(duration: 0.24).delay(0.08 + Double(index) * 0.025),
                            value: hasRevealed
                        )

                    if part.id != plan.parts.last?.id {
                        Divider()
                            .overlay(ResultColors.divider)
                    }
                }
            }
        }
    }
}

private struct ResultPartRow: View {
    let part: PCPart

    private var conditionColor: Color {
        part.condition == "全新"
            ? Color(red: 0.10, green: 0.39, blue: 0.70)
            : Color(red: 0.18, green: 0.48, blue: 0.21)
    }

    private var conditionBackground: Color {
        part.condition == "全新"
            ? Color(red: 0.91, green: 0.95, blue: 1.00)
            : Color(red: 0.92, green: 0.97, blue: 0.92)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: part.icon)
                .font(.system(size: 27, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(part.category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black)

                    Text(part.condition)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(conditionColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(conditionBackground, in: Capsule())
                }

                Text(part.model)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(part.price.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize()
        }
        .frame(minHeight: 64)
    }
}

private struct ResultCard<Content: View>: View {
    var verticalPadding: CGFloat = 15
    var horizontalPadding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 4)
    }
}

private enum ResultColors {
    static let divider = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let gaugeTrack = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let gaugeTick = Color(red: 0.78, green: 0.80, blue: 0.83)
    static let secondaryText = Color(red: 0.40, green: 0.43, blue: 0.50)
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
