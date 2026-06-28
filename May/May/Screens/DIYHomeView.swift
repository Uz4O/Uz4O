import SwiftUI

struct DIYHomeView: View {
    let onStartDIY: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 24)

                    hero(width: proxy.size.width)
                        .padding(.top, 22)

                    quickAccess
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    Text("DIY 能做什么")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.top, 58)

                    capabilityGrid
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                }
                .padding(.bottom, 30)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }

    private var header: some View {
        HStack {
            Text("UzBox")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.black)

            Spacer()

            Image(systemName: "bell")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .accessibilityLabel("通知")
        }
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Image("DIYHardwareHero")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.59, 252), height: 278)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 10, y: 48)

            VStack(alignment: .leading, spacing: 0) {
                Text("当前功能")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .padding(.bottom, 18)

                Text("DIY 自由选配")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .padding(.bottom, 10)

                Text("自己选硬件，App 帮你实时检查\n兼容性和预算")
                    .font(.system(size: 14.5, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Color.black.opacity(0.70))
                    .lineSpacing(8)
                    .padding(.bottom, 25)

                VStack(alignment: .leading, spacing: 10) {
                    heroBullet("智能统计总价")
                    heroBullet("自动检测兼容性")
                    heroBullet("AI 给出优化建议")
                }

                Button(action: onStartDIY) {
                    HStack(spacing: 18) {
                        Text("开始 DIY")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 43)
                    .background(.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开始 DIY")
                .padding(.top, 27)
            }
            .frame(width: 246, alignment: .leading)
            .padding(.leading, 36)

            HStack(spacing: 8) {
                Circle().fill(.black)
                Circle().fill(Color.black.opacity(0.13))
                Circle().fill(Color.black.opacity(0.13))
                Circle().fill(Color.black.opacity(0.13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 6)
            .offset(y: 366)
        }
        .frame(height: 384)
        .clipped()
    }

    private func heroBullet(_ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12, weight: .medium))
            Text(title)
                .font(.system(size: 14, weight: .regular))
        }
        .foregroundStyle(Color.black.opacity(0.58))
    }

    private var quickAccess: some View {
        HStack(alignment: .top, spacing: 0) {
            DIYQuickItem(icon: "cpu", title: "选 CPU")
            DIYQuickItem(icon: "rectangle.3.group", title: "选显卡")
            DIYQuickItem(icon: "square.grid.3x3.square", title: "选主板")
            DIYQuickItem(icon: "memorychip", title: "选内存")
            DIYQuickItem(icon: "square.grid.2x2", title: "更多配件")
        }
    }

    private var capabilityGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                DIYCapabilityCard(icon: "yensign.circle", title: "总价实时统计", subtitle: "所选配件总价实时更新")
                DIYCapabilityCard(icon: "bolt", title: "功耗估算", subtitle: "整机功耗预估与电源推荐")
            }
            GridRow {
                DIYCapabilityCard(icon: "checkmark.shield", title: "兼容性检测", subtitle: "自动检测硬件兼容性问题")
                DIYCapabilityCard(icon: "chart.bar", title: "瓶颈分析", subtitle: "分析整机性能短板与平衡性")
            }
        }
    }
}

private struct DIYQuickItem: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 50, height: 50)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.black.opacity(0.055), radius: 16, x: 0, y: 8)

                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct DIYCapabilityCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.035), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 14, x: 0, y: 7)
    }
}

#Preview {
    DIYHomeView(onStartDIY: {})
}
