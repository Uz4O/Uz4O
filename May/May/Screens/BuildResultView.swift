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
            VStack(spacing: 16) {
                resultHeader
                    .padding(.bottom, 4)

                PerformanceCard()
                PartsListCard(plan: plan, isVisible: isVisible, hasRevealed: hasRevealed)
                TotalPriceSection(totalPrice: plan.totalPrice)

                PrimaryButton(title: "保存配置单", icon: nil, action: {}, backgroundColor: .black)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
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
        HStack(alignment: .top, spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 5) {
                Text("配置方案详情")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)

                Text(plan.useCase)
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

private struct PerformanceCard: View {
    var body: some View {
        ResultCard {
            VStack(alignment: .leading, spacing: 11) {
                Text("游戏性能表现")
                    .font(.system(size: 16, weight: .bold))
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

private struct TotalPriceSection: View {
    let totalPrice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("总计")
                .font(.system(size: 13))
                .foregroundStyle(ResultColors.secondaryText)

            Text(totalPrice.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 4)
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
                    .font(.system(size: 20, weight: .bold))
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
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(part.category)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)

                    Text(part.condition)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(conditionColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(conditionBackground, in: Capsule())
                }

                Text(part.model)
                    .font(.system(size: 13.5))
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
        .frame(minHeight: 72)
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
            .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

private enum ResultColors {
    static let divider = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let gaugeTrack = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let secondaryText = Color(red: 0.40, green: 0.43, blue: 0.50)
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
