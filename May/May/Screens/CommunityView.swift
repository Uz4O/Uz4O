import SwiftUI

struct CommunityView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void

    @State private var selectedPost: CommunityPost?
    @State private var isComposerPresented = false

    private let posts = CommunityPost.featuredFeed

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("硬件讨论社区")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.top, 8)

            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            Button {
                                selectedPost = post
                            } label: {
                                CommunityForumRow(post: post, style: .home)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            if index != posts.count - 1 {
                                Divider()
                                    .padding(.leading, 42)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.bottom, 88)
                }

                Button {
                    isComposerPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(AppTheme.primaryButton, in: Circle())
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
                .padding(.bottom, 12)
            }

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
        .sheet(item: $selectedPost) { post in
            CommunityDetailView(post: post)
        }
        .sheet(isPresented: $isComposerPresented) {
            CommunityComposerView()
        }
    }
}

struct CommunityPostCard: View {
    let post: CommunityPost
    var isCompact: Bool

    var body: some View {
        CommunityForumRow(post: post, style: .home)
            .padding(.vertical, 14)
    }
}

struct CommunityForumRow: View {
    enum Style {
        case home
        case community

        var avatarSize: CGFloat {
            switch self {
            case .home:
                return 30
            case .community:
                return 40
            }
        }

        var authorFont: Font {
            switch self {
            case .home:
                return .system(size: 13, weight: .bold)
            case .community:
                return .system(size: 17, weight: .bold)
            }
        }

        var timeFont: Font {
            switch self {
            case .home:
                return .system(size: 11)
            case .community:
                return .system(size: 14)
            }
        }

        var titleFont: Font {
            switch self {
            case .home:
                return .system(size: 15, weight: .bold)
            case .community:
                return .system(size: 20, weight: .bold)
            }
        }

        var summaryFont: Font {
            switch self {
            case .home:
                return .system(size: 12)
            case .community:
                return .system(size: 16)
            }
        }

        var verticalSpacing: CGFloat {
            switch self {
            case .home:
                return 8
            case .community:
                return 14
            }
        }

        var imageHeight: CGFloat {
            switch self {
            case .home:
                return 60
            case .community:
                return 82
            }
        }
    }

    let post: CommunityPost
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: style.verticalSpacing) {
            HStack(alignment: .top, spacing: 12) {
                CommunityAvatar(author: post.author, size: style.avatarSize)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(post.author.name)
                            .font(style.authorFont)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)

                        Text(post.author.subtitle)
                            .font(style.timeFont)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "ellipsis")
                            .font(.system(size: style == .home ? 13 : 16, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if post.isPinned {
                        Text("置顶")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(AppTheme.success.opacity(0.14), in: Capsule())
                    }
                }
            }

            Text((post.isPinned ? "✨ " : "") + post.title)
                .font(style.titleFont)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.summary)
                .font(style.summaryFont)
                .foregroundStyle(style == .home ? AppTheme.secondaryText : AppTheme.primaryText)
                .lineLimit(style == .home ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)

            if post.id == "value-build-may" {
                CommunityImageStrip(height: style.imageHeight)
            }

            CommunityStatsBar(stats: post.stats, style: style == .home ? .compact : .regular)
        }
    }
}

struct CommunityAvatar: View {
    let author: CommunityAuthor
    var size: CGFloat = 26

    var body: some View {
        Text(author.avatarInitial)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [AppTheme.primaryText, Color(red: 0.33, green: 0.39, blue: 0.49)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
    }
}

struct CommunityImageStrip: View {
    var height: CGFloat = 58

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<4) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: imageColors[index],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if index == 0 {
                        MiniCaseThumbnail()
                    } else {
                        VStack(spacing: 7) {
                            HStack(spacing: 5) {
                                Circle().fill(Color.white.opacity(0.86)).frame(width: 12, height: 12)
                                Circle().fill(Color.white.opacity(0.62)).frame(width: 12, height: 12)
                            }
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.65))
                                .frame(width: 42, height: 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var imageColors: [[Color]] {
        [
            [Color(red: 0.86, green: 0.90, blue: 0.95), Color(red: 0.49, green: 0.56, blue: 0.66)],
            [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.31, green: 0.34, blue: 0.42)],
            [Color(red: 0.12, green: 0.10, blue: 0.22), Color(red: 0.32, green: 0.21, blue: 0.64)],
            [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.08, green: 0.31, blue: 0.78)]
        ]
    }
}

private struct MiniCaseThumbnail: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.30))
                .frame(width: 48, height: 48)

            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(
                    colors: [Color(red: 0.93, green: 0.96, blue: 1.0), Color(red: 0.65, green: 0.72, blue: 0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 42)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.50))
                .frame(width: 15, height: 30)
                .offset(x: -7)

            VStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.90))
                        .frame(width: 10, height: 10)
                }
            }
            .offset(x: 10)
        }
    }
}

struct CommunityStatsBar: View {
    enum Style {
        case compact
        case regular

        var fontSize: CGFloat {
            switch self {
            case .compact:
                return 11
            case .regular:
                return 14
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact:
                return 13
            case .regular:
                return 17
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact:
                return 24
            case .regular:
                return 34
            }
        }
    }

    let stats: CommunityStats
    var style: Style = .compact

    var body: some View {
        HStack(spacing: style.spacing) {
            stat(icon: "heart", value: stats.likes)
            stat(icon: "bubble.left", value: stats.comments)
            stat(icon: "hand.thumbsup", value: stats.saves)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.secondaryText)
    }

    private func stat(icon: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: style.iconSize, weight: .medium))
            Text("\(value)")
                .font(.system(size: style.fontSize, weight: .medium))
        }
    }
}

#Preview {
    CommunityView(selectedTab: .constant(.community), onSelectTab: { _ in })
}
