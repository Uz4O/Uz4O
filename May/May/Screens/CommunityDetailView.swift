import SwiftUI

struct CommunityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: AppSession
    let onContentChanged: () -> Void

    @State private var post: CommunityPost
    @State private var comments: [CommunityComment] = []
    @State private var errorMessage: String?
    @State private var showsDeletePostConfirmation = false
    @State private var pendingCommentDeletion: CommunityComment?
    @State private var pendingBlockAuthor: CommunityAuthor?
    @State private var reportTargetType = "post"
    @State private var reportTargetID = ""
    @State private var showsReportReasons = false
    @State private var newComment = ""
    @State private var isSubmittingComment = false

    init(
        session: AppSession,
        post: CommunityPost,
        onContentChanged: @escaping () -> Void = {}
    ) {
        self.session = session
        self.onContentChanged = onContentChanged
        _post = State(initialValue: post)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        postCard
                        commentsCard
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .task { await loadDetail() }
        .confirmationDialog("选择举报原因", isPresented: $showsReportReasons) {
            ForEach(CommunityReportReason.allCases, id: \.rawValue) { reason in
                Button(reason.title) { report(reason: reason) }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("确认删除帖子？", isPresented: $showsDeletePostConfirmation) {
            Button("删除", role: .destructive) { deletePost() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后帖子将立即停止公开展示。")
        }
        .alert("确认删除评论？", isPresented: commentDeleteIsPresented) {
            Button("删除", role: .destructive) { deletePendingComment() }
            Button("取消", role: .cancel) { pendingCommentDeletion = nil }
        }
        .alert("确认屏蔽该用户？", isPresented: blockIsPresented) {
            Button("屏蔽", role: .destructive) { blockPendingAuthor() }
            Button("取消", role: .cancel) { pendingBlockAuthor = nil }
        } message: {
            Text("屏蔽后将不再向你展示该用户的社区内容。")
        }
        .alert("操作失败", isPresented: errorIsPresented) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            actionMenu(for: post.availableActions, targetType: "post", targetID: post.id, author: post.author)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .frame(height: 48)
    }

    private var postCard: some View {
        SoftCard(radius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 9) {
                    CommunityAvatar(author: post.author, size: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.author.name)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(post.createdAt)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }

                Text(post.body)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(post.parts, id: \.self) { part in
                    Text(part)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.primaryText)
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
    }

    private var commentsCard: some View {
        SoftCard(radius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("全部评论 (\(comments.count))")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                if comments.isEmpty {
                    Text("暂时没有评论")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(comment.author.name)
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            actionMenu(
                                for: comment.availableActions,
                                targetType: "comment",
                                targetID: comment.id,
                                author: comment.author,
                                comment: comment
                            )
                        }
                        Text(comment.body)
                            .font(.appBody)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(.vertical, 6)
                }

                HStack(spacing: 10) {
                    TextField("写下你的评论...", text: $newComment, axis: .vertical)
                        .font(.appBody)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: newComment) { _, value in
                            if value.count > 2000 {
                                newComment = String(value.prefix(2000))
                            }
                        }

                    Button(isSubmittingComment ? "发送中" : "发送") {
                        submitComment()
                    }
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(!canSubmitComment || isSubmittingComment)
                    .opacity(canSubmitComment && !isSubmittingComment ? 1 : 0.45)
                }
            }
            .padding(16)
        }
    }

    private func actionMenu(
        for actions: [CommunityAction],
        targetType: String,
        targetID: String,
        author: CommunityAuthor,
        comment: CommunityComment? = nil
    ) -> some View {
        Menu {
            if actions.contains(.delete) {
                Button("删除", role: .destructive) {
                    if let comment {
                        pendingCommentDeletion = comment
                    } else {
                        showsDeletePostConfirmation = true
                    }
                }
            }
            if actions.contains(.report) {
                Button("举报") {
                    reportTargetType = targetType
                    reportTargetID = targetID
                    showsReportReasons = true
                }
            }
            if actions.contains(.block) {
                Button("屏蔽用户", role: .destructive) {
                    pendingBlockAuthor = author
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 32, height: 32)
        }
    }

    private func loadDetail() async {
        guard let token = session.accessToken else { return }
        do {
            let detail = try await session.api.communityPostDetail(postID: post.id, token: token)
            post = detail.0
            comments = detail.1
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法加载帖子"
        }
    }

    private func deletePost() {
        guard let token = session.accessToken else { return }
        Task {
            do {
                try await session.api.deleteCommunityPost(id: post.id, token: token)
                onContentChanged()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "删除失败"
            }
        }
    }

    private func deletePendingComment() {
        guard let comment = pendingCommentDeletion, let token = session.accessToken else { return }
        Task {
            do {
                try await session.api.deleteCommunityComment(id: comment.id, token: token)
                comments.removeAll { $0.id == comment.id }
                pendingCommentDeletion = nil
                onContentChanged()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "删除失败"
            }
        }
    }

    private func report(reason: CommunityReportReason) {
        guard let token = session.accessToken else { return }
        Task {
            do {
                try await session.api.reportCommunityContent(
                    targetType: reportTargetType,
                    targetID: reportTargetID,
                    reason: reason,
                    token: token
                )
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "举报失败"
            }
        }
    }

    private var canSubmitComment: Bool {
        newComment.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func submitComment() {
        guard let token = session.accessToken else { return }
        let body = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            isSubmittingComment = true
            defer { isSubmittingComment = false }
            do {
                let comment = try await session.api.createCommunityComment(
                    postID: post.id,
                    body: body,
                    token: token
                )
                comments.append(comment)
                newComment = ""
                onContentChanged()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "评论发布失败"
            }
        }
    }

    private func blockPendingAuthor() {
        guard let author = pendingBlockAuthor, let token = session.accessToken else { return }
        Task {
            do {
                try await session.api.blockCommunityAccount(id: author.id, token: token)
                pendingBlockAuthor = nil
                onContentChanged()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "屏蔽失败"
            }
        }
    }

    private var commentDeleteIsPresented: Binding<Bool> {
        Binding(
            get: { pendingCommentDeletion != nil },
            set: { if !$0 { pendingCommentDeletion = nil } }
        )
    }

    private var blockIsPresented: Binding<Bool> {
        Binding(
            get: { pendingBlockAuthor != nil },
            set: { if !$0 { pendingBlockAuthor = nil } }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    CommunityDetailView(session: AppSession(), post: CommunityPost.featuredFeed[0])
}
