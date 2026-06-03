import SwiftUI

struct DIYBuildView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "自由 DIY 装机", onBack: onBack)
                .padding(.top, 8)

            SoftCard(radius: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("我的配置单")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("共 7 个配件")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("¥ 8566")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Spacer()

                    Image("PCTower")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                }
                .padding(18)
            }

            SoftCard(radius: 16) {
                VStack(spacing: 18) {
                    ForEach(AppMockData.parts) { part in
                        PartRow(part: part)
                    }
                }
                .padding(18)
            }

            Spacer()

            HStack(spacing: 16) {
                PrimaryButton(title: "保存配置单", icon: nil, action: {})

                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 86, height: 48)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 22)
    }
}

#Preview {
    DIYBuildView(onBack: {})
}
