import SwiftUI

struct BuildOptionsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false

    let response: BuildOptionsResponseDTO
    let onBack: () -> Void
    let onSelect: (BuildOptionDTO) -> Void

    private var isVisible: Bool {
        hasRevealed || reduceMotion
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "选择配置方案", trailingIcon: nil, onBack: onBack)
                    .padding(.top, 8)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.28).delay(0.06), value: hasRevealed)

                VStack(alignment: .leading, spacing: 8) {
                    Text("可选方案")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("配置方向：\(response.direction.displayName)")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 40)
                .padding(.horizontal, 4)
                .padding(.bottom, 22)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.88).delay(0.12), value: hasRevealed)

                LazyVStack(spacing: 16) {
                    ForEach(Array(response.options.enumerated()), id: \.element.id) { index, option in
                        BuildOptionCard(option: option) {
                            onSelect(option)
                        }
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 22)
                        .blur(radius: isVisible ? 0 : 4)
                        .animation(
                            .spring(response: 0.56, dampingFraction: 0.86)
                                .delay(0.18 + Double(index) * 0.09),
                            value: hasRevealed
                        )
                    }
                }

                if !response.unavailableModes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(response.unavailableModes, id: \.rawValue) { mode in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(width: 18)

                                Text(
                                    response.unavailableModeReasons?[mode.rawValue]
                                        ?? "当前预算下没有可靠的\(mode.displayName)方案"
                                )
                                    .font(.appCaption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.975, green: 0.981, blue: 0.988).ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            hasRevealed = true
        }
    }
}

private struct BuildOptionCard: View {
    let option: BuildOptionDTO
    let onSelect: () -> Void

    private var cpuName: String {
        option.part(for: .cpu).name
    }

    private var gpuName: String {
        let gpu = option.part(for: .gpu)

        switch gpu.componentId {
        case "rx-9060-xt-8gb":
            return "9060XT 8G"
        case "rx-9060-xt-12gb":
            return "9060XT 12G"
        case "rx-9060-xt-16gb":
            return "9060XT 16G"
        default:
            return HardwareCatalog.gpus.first { $0.id == gpu.componentId }?.name ?? gpu.name
        }
    }

    private var mode: BuildPurchaseModeDTO {
        option.details.purchaseMode
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 10) {
                            Text("\(mode.displayName)方案")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(.black)

                            Text(mode.badgeTitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .frame(height: 22)
                                .background(mode.badgeColor, in: Capsule())
                        }

                        Text("\(cpuName) + \(gpuName)")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.30, green: 0.31, blue: 0.34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 20)
                        .offset(x: 6)
                }

                Divider()
                    .overlay(AppTheme.border.opacity(0.9))
                    .padding(.top, 22)

                HStack(alignment: .firstTextBaseline) {
                    Text("参考总价")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(option.referenceTotalText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 25)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .micro3DSurface(cornerRadius: 22)
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看方案详情")
    }
}

private extension BuildPurchaseModeDTO {
    var badgeTitle: String {
        switch self {
        case .new: "全新"
        case .used: "二手"
        case .mixed: "混合"
        }
    }

    var badgeColor: Color {
        switch self {
        case .new: Color(red: 0.29, green: 0.43, blue: 0.68)
        case .used: Color(red: 0.27, green: 0.52, blue: 0.43)
        case .mixed: Color(red: 0.76, green: 0.43, blue: 0.27)
        }
    }
}
