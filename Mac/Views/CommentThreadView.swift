import SwiftUI

struct CommentThreadView: View {
    let root: VideoComment
    let oid: Int64
    let type: String
    let onReply: (VideoComment, Int64?) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isExpanded = false
    @State private var replies: [VideoComment] = []
    @State private var total = 0
    @State private var loadedPage = 0
    @State private var isLoading = false
    @State private var error: String?

    private var expandableCount: Int { max(root.replyCount, root.replies.count) }
    private var hasMore: Bool { replies.count < total }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if isExpanded, !replies.isEmpty {
                ForEach(replies) { reply in
                    replyRow(reply)
                }
            } else {
                ForEach(root.replies) { reply in
                    replyRow(reply)
                }
            }

            if isExpanded, isLoading, replies.isEmpty {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载回复…")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .padding(.leading, 33)
                .padding(.top, 2)
            }

            if let error {
                HStack(spacing: 8) {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Button("重试") {
                        Task {
                            await loadPage(replies.isEmpty ? 1 : loadedPage + 1, reset: replies.isEmpty)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                }
                .padding(.leading, 33)
            }

            if isExpanded, hasMore, !replies.isEmpty {
                Button {
                    Task { await loadPage(loadedPage + 1, reset: false) }
                } label: {
                    Text(isLoading ? "加载中…" : "加载更多回复")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .padding(.leading, 33)
            }

            if (expandableCount > 0 && (expandableCount > root.replies.count || !root.replies.isEmpty))
                || isExpanded {
                Button(action: toggle) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起回复" : "共 \(expandableCount) 条回复")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.brand)
                }
                .buttonStyle(.plain)
                .padding(.leading, 33)
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
        .task {
#if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BTB_THREAD_ROOT"],
               Int64(raw) == root.id,
               !isExpanded,
               expandableCount > root.replies.count {
                toggle()
            }
#endif
        }
    }

    private func toggle() {
        withAnimation(.easeOut(duration: 0.16)) {
            isExpanded.toggle()
        }
        guard isExpanded, replies.isEmpty, !isLoading else { return }
        Task { await loadPage(1, reset: true) }
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await model.fetchCommentThread(
                oid: oid,
                type: type,
                rootID: root.id,
                page: page
            )
            if reset {
                replies = result.items
            } else {
                var seen = Set(replies.map(\.id))
                replies.append(contentsOf: result.items.filter { seen.insert($0.id).inserted })
            }
            total = max(result.total, replies.count)
            loadedPage = page
        } catch {
            self.error = "回复加载失败"
        }
    }

    private func replyRow(_ reply: VideoComment) -> some View {
        HStack(alignment: .top, spacing: 9) {
            AvatarView(url: reply.avatarURL, size: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(reply.author)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text(reply.timeText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                Text(reply.message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.text(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Button {
                    onReply(reply, root.id)
                } label: {
                    Text("回复")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
            }
        }
        .padding(.top, 4)
    }
}
