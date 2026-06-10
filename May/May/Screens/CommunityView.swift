import SwiftUI

struct CommunityView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void

    @State private var selectedPost: CommunityPost?
    @State private var isComposerPresented = false
    private let posts = CommunityPost.featuredFeed

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("硬件讨论社区")
                        .font(.system(size: 29, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("分享装机经验，交流硬件知识")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.top, 12)

            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { post in
                            Button {
                                selectedPost = post
                            } label: {
                                CommunityPostSurface(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 74)
                }

                Button {
                    isComposerPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black, in: Circle())
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .padding(.bottom, 14)
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

private struct CommunityPostSurface: View {
    let post: CommunityPost

    var body: some View {
        CommunityForumRow(post: post, style: .community)
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .modifier(AppTheme.cardShadow)
    }
}

struct CommunityPostCard: View {
    let post: CommunityPost
    var isCompact: Bool

    var body: some View {
        CommunityForumRow(post: post, style: isCompact ? .home : .community)
    }
}

struct CommunityForumRow: View {
    enum Style: Equatable {
        case home
        case community

        var avatarSize: CGFloat { self == .home ? 30 : 38 }
        var authorFont: Font { .system(size: self == .home ? 13 : 14, weight: .bold) }
        var timeFont: Font { .system(size: self == .home ? 11 : 12) }
        var titleFont: Font { .system(size: self == .home ? 15 : 18, weight: .bold) }
        var summaryFont: Font { .system(size: self == .home ? 12 : 13) }
        var spacing: CGFloat { self == .home ? 8 : 12 }
    }

    let post: CommunityPost
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            HStack(spacing: 10) {
                CommunityAvatar(author: post.author, size: style.avatarSize)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(post.author.name)
                        .font(style.authorFont)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(post.author.subtitle)
                        .font(style.timeFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if post.isPinned {
                Text("置顶")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            Text((post.isPinned ? "✦ " : "") + post.title)
                .font(style.titleFont)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text(post.summary)
                .font(style.summaryFont)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(style == .home ? 1 : 2)

            if post.id == "value-build-may" && style == .community {
                CommunityImageStrip(height: 72)
            }

            CommunityStatsBar(stats: post.stats, style: style == .home ? .compact : .regular)
        }
    }
}

struct CommunityAvatar: View {
    let author: CommunityAuthor
    var size: CGFloat = 26

    var body: some View {
        MascotAvatar(size: size)
    }
}

struct CommunityImageStrip: View {
    var height: CGFloat = 58

    var body: some View {
        Image("CommunityHardwareStrip")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CommunityStatsBar: View {
    enum Style: Equatable {
        case compact
        case regular

        var fontSize: CGFloat { self == .compact ? 11 : 13 }
        var iconSize: CGFloat { self == .compact ? 13 : 16 }
        var spacing: CGFloat { self == .compact ? 24 : 30 }
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
