import SwiftUI

struct ComputerProfileView: View {
    let hardwareProfile: HardwareProfile
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "我的电脑档案", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            SoftCard(radius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hardwareProfile.wasSkipped ? "还没有记录电脑配置" : "当前电脑配置")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(hardwareProfile.wasSkipped ? "你在进入 App 前跳过了电脑配置，后续可以在这里补充。" : hardwareProfile.summary)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SoftCard(radius: 18) {
                VStack(spacing: 0) {
                    ComputerProfileRow(title: "CPU", value: hardwareProfile.cpu, icon: "cpu")
                    Divider().padding(.leading, 42)
                    ComputerProfileRow(title: "显卡", value: hardwareProfile.gpu, icon: "display")
                    Divider().padding(.leading, 42)
                    ComputerProfileRow(title: "主板", value: hardwareProfile.motherboard, icon: "menucard")
                    Divider().padding(.leading, 42)
                    ComputerProfileRow(title: "内存", value: hardwareProfile.memory, icon: "rectangle.stack")
                    Divider().padding(.leading, 42)
                    ComputerProfileRow(title: "硬盘", value: hardwareProfile.storage, icon: "externaldrive")
                    Divider().padding(.leading, 42)
                    ComputerProfileRow(title: "电源", value: hardwareProfile.powerSupply, icon: "bolt")
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 22)
    }
}

private struct ComputerProfileRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 30, height: 30)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Text(value)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 13)
    }
}

#Preview {
    ComputerProfileView(hardwareProfile: .skipped, onBack: {})
}
