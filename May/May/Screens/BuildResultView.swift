import SwiftUI

struct BuildResultView: View {
    let plan: BuildPlan
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "配置方案详情", onBack: onBack)
                    .padding(.top, 8)

                Text(AIContentDisclosure.text)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                BuildHeroCard(plan: plan)

                VStack(alignment: .leading, spacing: 0) {
                    Text("配件清单")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.bottom, 8)

                    ForEach(plan.parts) { part in
                        ResultPartRow(part: part)
                        if part.id != plan.parts.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("价格可能随市场波动，请以实际购买时为准。")
                }
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

                PrimaryButton(title: "保存配置单", icon: "tray.and.arrow.down", action: {})
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }
}

private struct BuildHeroCard: View {
    let plan: BuildPlan

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.035, green: 0.039, blue: 0.047))

                Image("PCTower")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.height * 0.92)
                    .offset(x: 16, y: 8)

                VStack(alignment: .leading, spacing: 7) {
                    Text(plan.name)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(plan.useCase)
                        .font(.appBody)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)

                    Spacer(minLength: 10)

                    Text("配置总价")
                        .font(.appCaption)
                        .foregroundStyle(.white.opacity(0.58))

                    Text(plan.totalPrice)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(22)
                .frame(width: proxy.size.width * 0.62, height: proxy.size.height, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .aspectRatio(1.72, contentMode: .fit)
    }
}

private struct ResultPartRow: View {
    let part: PCPart

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: part.icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(part.category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(part.condition)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.softSurface, in: Capsule())
                }

                Text(part.model)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(part.price)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
