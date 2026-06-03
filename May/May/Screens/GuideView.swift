import SwiftUI

struct GuideView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "装机指南", onBack: onBack)
                .padding(.top, 8)

            SoftCard(radius: 22) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("装机流程")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)

                    VStack(spacing: 0) {
                        ForEach(Array(AppMockData.guideSteps.enumerated()), id: \.element.id) { index, step in
                            StepRow(step: step, isLast: index == AppMockData.guideSteps.count - 1)
                        }
                    }
                }
                .padding(22)
            }

            Spacer()

            PrimaryButton(title: "开始装机指南", icon: nil, action: {})
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 22)
    }
}

private struct StepRow: View {
    let step: BuildStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Text(step.number)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 25)
                    .background(AppTheme.primaryText, in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1, height: 30)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(step.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.top, 1)

            Spacer()
        }
        .frame(height: isLast ? 36 : 55)
    }
}

#Preview {
    GuideView(onBack: {})
}
