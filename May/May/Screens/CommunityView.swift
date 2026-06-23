import SwiftUI

struct CommunityView: View {
    @ObservedObject var session: AppSession
    @State private var selectedPost: CommunityPost?
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showsComposer = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width)

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        CommunityHeader(onCompose: { showsComposer = true })
                            .padding(.top, 8)
                            .padding(.bottom, 18)

                        if isLoading && posts.isEmpty {
                            ProgressView("正在加载社区...")
                                .padding(.top, 60)
                        } else if let errorMessage, posts.isEmpty {
                            ContentUnavailableView(
                                "社区加载失败",
                                systemImage: "wifi.exclamationmark",
                                description: Text(errorMessage)
                            )
                            Button("重试") { loadFeed() }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.primaryButton)
                        } else if posts.isEmpty {
                            ContentUnavailableView(
                                "暂时没有帖子",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("发布第一条装机讨论吧")
                            )
                            .padding(.top, 40)
                        }

                        ForEach(posts) { post in
                            Button {
                                selectedPost = post
                            } label: {
                                CommunityPostSurface(post: post, contentWidth: contentWidth)
                            }
                            .buttonStyle(.plain)
                        }

                        Color.clear.frame(height: 2)
                    }
                    .frame(width: contentWidth)
                    .padding(.bottom, 118)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
        }
        .sheet(item: $selectedPost) { post in
            CommunityDetailView(
                session: session,
                post: post,
                onContentChanged: loadFeed
            )
        }
        .sheet(isPresented: $showsComposer) {
            CommunityComposerView(
                session: session,
                onPublished: {
                    showsComposer = false
                    loadFeed()
                }
            )
        }
        .task { await loadFeedAsync() }
    }

    private func loadFeed() {
        Task { await loadFeedAsync() }
    }

    private func loadFeedAsync() async {
        guard let token = session.accessToken else {
            errorMessage = "登录状态已失效，请重新登录"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await session.api.communityFeed(token: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "网络请求失败"
        }
    }
}

private struct CommunityHeader: View {
    let onCompose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("硬件讨论社区")
                    .font(.system(size: 29, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)

                Text("交流装机经验 · 分享配置 · 解决问题")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button(action: onCompose) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("发布帖子")
        }
    }
}

private struct CommunityPostSurface: View {
    let post: CommunityPost
    let contentWidth: CGFloat

    var body: some View {
        CommunityForumRow(post: post, style: .community, imageWidth: contentWidth)
            .padding(.vertical, 18)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.border.opacity(0.8))
                    .frame(height: 1)
            }
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

        var avatarSize: CGFloat { self == .home ? 30 : 32 }
        var authorFont: Font { .system(size: self == .home ? 13 : 14, weight: .regular) }
        var timeFont: Font { .system(size: self == .home ? 11 : 11) }
        var contentFont: Font { .system(size: self == .home ? 13 : 14, weight: .regular) }
        var spacing: CGFloat { self == .home ? 8 : 9 }
    }

    let post: CommunityPost
    let style: Style
    var imageWidth: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            HStack(alignment: .top, spacing: 10) {
                CommunityAvatar(author: post.author, size: style.avatarSize)

                VStack(alignment: .leading, spacing: 3) {
                    Text(post.author.name)
                        .font(style.authorFont)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(post.author.subtitle)
                        .font(style.timeFont)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                if style == .community {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 28, height: 28)
                        .accessibilityLabel("更多")
                }
            }

            Text(post.summary)
                .font(style.contentFont)
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(4)
                .lineLimit(style == .home ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)

            if let image = post.image, let imageWidth, style == .community {
                CommunityPostImageView(image: image, width: imageWidth)
                    .padding(.top, 6)
            }

            CommunityStatsBar(stats: post.stats, style: style == .home ? .compact : .regular)
                .padding(.top, style == .home ? 0 : 4)
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

struct CommunityPostImageView: View {
    let image: CommunityPostImage
    let width: CGFloat

    var body: some View {
        ZStack {
            AppTheme.softSurface

            Image(image.assetName)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .accessibilityLabel(image.accessibilityLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(image.displayHeight(forWidth: Double(width))))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CommunityStatsBar: View {
    enum Style: Equatable {
        case compact
        case regular

        var fontSize: CGFloat { self == .compact ? 12 : 13 }
        var iconSize: CGFloat { self == .compact ? 13 : 15 }
        var spacing: CGFloat { self == .compact ? 24 : 30 }
    }

    let stats: CommunityStats
    var style: Style = .compact

    var body: some View {
        HStack(spacing: style.spacing) {
            stat(icon: "heart", value: stats.likes)
            stat(icon: "bubble.left", value: stats.comments)
            stat(icon: "bookmark", value: stats.saves)
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
    CommunityView(session: AppSession())
}
