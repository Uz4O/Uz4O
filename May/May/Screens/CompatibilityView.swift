import SwiftUI

struct CompatibilityView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "兼容性检测", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            SoftCard(radius: 22) {
                VStack(spacing: 26) {
                    HStack(spacing: 18) {
                        ZStack {
                            Image(systemName: "shield")
                                .font(.system(size: 62, weight: .light))
                                .foregroundStyle(AppTheme.border)
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                        }
                        .frame(width: 70, height: 76)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("兼容性检测结果")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("全部兼容")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                            Text("未发现硬件相容问题")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text("检测清单")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)

                        ForEach(AppMockData.parts) { part in
                            PartRow(part: part, showsCheckmark: true)
                        }
                    }

                    PrimaryButton(title: "重新检测", icon: nil, action: {})

                    Button("保存报告") {}
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .buttonStyle(.plain)
                }
                .padding(22)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

#Preview {
    CompatibilityView(onBack: {})
}
