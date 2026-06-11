import SwiftUI

struct CommunityDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let post: CommunityPost

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .frame(height: 48)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        SoftCard(radius: 16) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 9) {
                                    CommunityAvatar(author: post.author, size: 32)
                                        .padding(.top, 1)

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(post.author.name)
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundStyle(AppTheme.primaryText)
                                                .lineLimit(1)

                                            Text(post.createdAt)
                                                .font(.system(size: 11))
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }

                                    Spacer()

                                    Button(action: {}) {
                                        Text("+ 关注")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .frame(height: 26)
                                            .background(AppTheme.primaryButton, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text(post.body)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(alignment: .leading, spacing: 7) {
                                    ForEach(post.parts, id: \.self) { part in
                                        Text(part)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundStyle(AppTheme.primaryText)
                                    }
                                }

                                if let image = post.image {
                                    CommunityPostImageView(image: image, width: 296)
                                }

                                HStack(spacing: 8) {
                                    ForEach(post.tags, id: \.self) { tag in
                                        Text("# \(tag)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .padding(.horizontal, 9)
                                            .frame(height: 26)
                                            .background(AppTheme.softSurface, in: Capsule())
                                    }
                                }

                                CommunityStatsBar(stats: post.stats, style: .compact)
                            }
                            .padding(16)
                        }

                        SoftCard(radius: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("全部评论 (\(post.stats.comments))")
                                        .font(.appSubheadline)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                HStack(spacing: 10) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Text("写下你的评论...")
                                        .font(.appCaption)
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(AppTheme.softSurface, in: Capsule())
                            }
                            .padding(16)
                        }
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

#Preview {
    CommunityDetailView(post: CommunityPost.featuredFeed[0])
}
