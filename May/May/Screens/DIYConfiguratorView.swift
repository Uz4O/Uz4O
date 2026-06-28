import SwiftUI

struct DIYConfiguratorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onBack: () -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)
    }

    private var actionLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(spacing: 12))
        } else {
            AnyLayout(HStackLayout(spacing: 12))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DIYConfiguratorHeader(onBack: onBack)

                DIYConfiguratorIntro()
                    .padding(.top, 30)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(DIYConfiguratorLayout.parts) { part in
                        DIYPartCard(part: part)
                    }
                }
                .padding(.top, 30)

                DIYRealtimeSummary()
                    .padding(.top, 18)

                actionLayout {
                    DIYStaticActionButton(title: "✦ AI 优化", isPrimary: false)
                    DIYStaticActionButton(title: "查看主机概况", isPrimary: true, showsArrow: true)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct DIYConfiguratorHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .diyScaledSystemFont(size: 18, weight: .semibold, relativeTo: .body)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回 DIY 首页")

            Spacer()

            Image(systemName: "bell")
                .diyScaledSystemFont(size: 22, weight: .regular, relativeTo: .title3)
                .frame(width: 38, height: 38)
                .accessibilityLabel("通知")
        }
        .foregroundStyle(.black)
    }
}

private struct DIYConfiguratorIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DIY 选配")
                .diyScaledSystemFont(size: 13, weight: .medium, relativeTo: .caption)
                .foregroundStyle(Color.black.opacity(0.48))

            Text("开始 DIY")
                .diyScaledSystemFont(size: 38, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(.black)
                .padding(.top, 10)

            Text("自由搭配硬件，实时检查兼容性与预算")
                .diyScaledSystemFont(size: 14, weight: .regular, relativeTo: .subheadline)
                .foregroundStyle(Color.black.opacity(0.52))
                .padding(.top, 12)
        }
    }
}

private struct DIYPartCard: View {
    let part: DIYConfiguratorPart

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(part.number)
                .diyScaledSystemFont(size: 12, weight: .regular, relativeTo: .caption)
                .foregroundStyle(Color.black.opacity(0.44))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: part.icon)
                .diyScaledSystemFont(size: 25, weight: .regular, relativeTo: .title2)
                .foregroundStyle(.black)
                .frame(width: 54, height: 54)
                .background(Color.black.opacity(0.035), in: Circle())
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text(part.title)
                .diyScaledSystemFont(size: 16, weight: .bold, relativeTo: .headline)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 15)

            Text(part.value)
                .diyScaledSystemFont(size: 11, weight: .regular, relativeTo: .caption2)
                .foregroundStyle(part.isSelected ? Color.black.opacity(0.76) : Color.black.opacity(0.42))
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Spacer(minLength: 6)

            selectionIndicator
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 214)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 27))
        .overlay {
            RoundedRectangle(cornerRadius: 27)
                .stroke(Color.black.opacity(0.09), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if part.isSelected {
            Image(systemName: "checkmark")
                .diyScaledSystemFont(size: 12, weight: .bold, relativeTo: .caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.green, in: Circle())
        } else {
            Image(systemName: "plus")
                .diyScaledSystemFont(size: 15, weight: .regular, relativeTo: .body)
                .foregroundStyle(.black)
                .frame(width: 30, height: 30)
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.black.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                }
        }
    }
}

private struct DIYRealtimeSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 7) {
                Text("实时检测")
                    .diyScaledSystemFont(size: 16, weight: .bold, relativeTo: .headline)

                Image(systemName: "waveform.path.ecg.rectangle")
                    .diyScaledSystemFont(size: 15, weight: .regular, relativeTo: .body)
            }
            .foregroundStyle(.black)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                    spacing: 16
                ) {
                    DIYSummaryColumn(label: "总价", value: "¥ 7997")
                    DIYSummaryColumn(label: "功耗", value: "428W")
                    DIYSummaryColumn(label: "兼容性", value: "完全兼容", isPositive: true)
                    DIYSummaryColumn(label: "预算状态", value: "预算内", isPositive: true)
                }
            } else {
                HStack(spacing: 7) {
                    DIYSummaryColumn(label: "总价", value: "¥ 7997")
                    Divider().frame(height: 36)
                    DIYSummaryColumn(label: "功耗", value: "428W")
                    Divider().frame(height: 36)
                    DIYSummaryColumn(label: "兼容性", value: "完全兼容", isPositive: true)
                    Divider().frame(height: 36)
                    DIYSummaryColumn(label: "预算状态", value: "预算内", isPositive: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.09), lineWidth: 0.8)
        }
    }
}

private struct DIYSummaryColumn: View {
    let label: String
    let value: String
    var isPositive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .diyScaledSystemFont(size: 10, weight: .regular, relativeTo: .caption2)
                .foregroundStyle(Color.black.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .diyScaledSystemFont(size: 13, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(isPositive ? Color.green : Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DIYStaticActionButton: View {
    let title: String
    let isPrimary: Bool
    var showsArrow = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if showsArrow {
                    Image(systemName: "chevron.right")
                        .diyScaledSystemFont(size: 14, weight: .semibold, relativeTo: .body)
                }
            }
            .diyScaledSystemFont(size: 15, weight: .medium, relativeTo: .body)
            .foregroundStyle(isPrimary ? Color.white : Color.black)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(isPrimary ? Color.black : Color.white, in: Capsule())
            .overlay {
                if !isPrimary {
                    Capsule().stroke(Color.black, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DIYScaledSystemFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight))
    }
}

private extension View {
    func diyScaledSystemFont(
        size: CGFloat,
        weight: Font.Weight,
        relativeTo textStyle: Font.TextStyle
    ) -> some View {
        modifier(DIYScaledSystemFont(size: size, weight: weight, relativeTo: textStyle))
    }
}

#Preview {
    DIYConfiguratorView(onBack: {})
}
