import SwiftUI

struct AestheticStylesView: View {
    let onOpenStyle: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(
                for: proxy.size.width,
                compactWidth: 344,
                expandedWidth: 406,
                sideMargin: 34
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("装机风格")
                        .font(.system(size: 29, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(AestheticBuildStyle.all) { style in
                            AestheticStyleGridCard(style: style) {
                                onOpenStyle(style.id)
                            }
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.bottom, 112)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

private struct AestheticStyleGridCard: View {
    let style: AestheticBuildStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(style.image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 158)
                    .clipped()
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 14,
                            topTrailingRadius: 14
                        )
                        .stroke(AppTheme.border.opacity(0.75), lineWidth: 0.8)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(style.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Text(style.startingCostLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                .background(
                    Color.white,
                    in: UnevenRoundedRectangle(
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 14
                    )
                )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.title)，\(style.startingCostLabel)")
    }
}

struct AestheticStyleRow: View {
    let style: AestheticBuildStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Text(style.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)

                        Text(style.startingCostLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.52))
                    }

                    Text("按这个风格装机  →")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        ForEach(style.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.black.opacity(0.62))
                                .frame(height: 22)
                                .padding(.horizontal, 10)
                                .background(Color.black.opacity(0.04), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 6)

                Image(style.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 106)
                    .offset(x: 12)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AestheticStylesView(onOpenStyle: { _ in })
}
