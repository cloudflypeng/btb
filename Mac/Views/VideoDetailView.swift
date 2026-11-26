import AppKit
import SwiftUI

struct VideoDetailView: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isDescriptionExpanded = false
    @State private var isTheater = {
#if DEBUG
        ProcessInfo.processInfo.environment["BTB_THEATER"] == "1"
#else
        false
#endif
    }()
    @AppStorage("player.autoplayNext") private var autoplayNext = true

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 1120 && !isTheater
            let theaterSize = isTheater ? theaterPlayerSize(in: proxy.size) : nil

            ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: isTheater ? 0 : 24) {
                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            mainColumn(theaterSize: theaterSize)
                            RelatedRailView(video: video, showsSkeleton: isContentLoading)
                                .frame(width: 342)
                        }
                    } else {
                        mainColumn(theaterSize: theaterSize)
                        if !isTheater {
                            RelatedRailView(video: video, showsSkeleton: isContentLoading)
                        }
                    }
                }
                .padding(.horizontal, isTheater ? 0 : 24)
                .padding(.top, isTheater ? 0 : 16)
                .padding(.bottom, isTheater ? 0 : 48)
                .frame(maxWidth: isTheater ? CGFloat.infinity : 1600, alignment: isTheater ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isTheater ? Color.black : Color.clear)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isTheater)
            .id(video.bvid)
            .task(id: video.bvid) {
                await model.loadWatchPage(for: video)
#if DEBUG
                let environment = ProcessInfo.processInfo.environment
                if environment["BTB_SCROLL_COMMENTS"] == "1" {
                    // Wait until the detail and comments have laid out; scrolling to an
                    // anchor that doesn't exist yet leaves the offset past the content.
                    for _ in 0..<50 where model.comments.isEmpty || isContentLoading {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let anchor = environment["BTB_THREAD_ROOT"]
                        .flatMap(Int64.init)
                        .map { "thread-\($0)" } ?? "comments"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        reader.scrollTo(anchor, anchor: .top)
                    }
                }
#endif
            }
            }
        }
        .background(AppTheme.background(scheme))
        .toolbar(isTheater ? .hidden : .visible, for: .windowToolbar)
        .overlay(alignment: .bottom) {
            toast
        }
        .animation(.easeOut(duration: 0.2), value: model.toastMessage)
    }

    private func mainColumn(theaterSize: CGSize?) -> some View {
        LazyVStack(
            alignment: .leading,
            spacing: isTheater ? 0 : 16,
            pinnedViews: isTheater ? [] : [.sectionHeaders]
        ) {
            Section {
                if !isTheater {
                    if isContentLoading {
                        DetailContentSkeleton()
                    } else {
                        if let error = model.detailError {
                            ErrorBanner(text: error) {
                                Task { await model.loadWatchPage(for: video, force: true) }
                            }
                        }

                        Text(displayTitle)
                            .font(.system(size: 22, weight: .bold))
                            .lineSpacing(3)
                            .foregroundStyle(AppTheme.text(scheme))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        descriptionCard

                        if !model.videoTags.isEmpty {
                            tagStrip
                        }

                        if model.isLoadingAI {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在生成 AI 总结…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.secondary(scheme))
                            }
                        } else if let conclusion = model.aiConclusion {
                            aiSummaryCard(conclusion)
                        }

                        CommentsSectionView(video: video)
                            .padding(.top, 10)
                            .id("comments")
                    }
                }
            } header: {
                VStack(spacing: 0) {
                    InlinePlayerView(video: video, isTheater: $isTheater)
                        .id(video.bvid)
                        .frame(width: theaterSize?.width, height: theaterSize?.height)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Pinned with the player so actions never scroll away.
                    if !isTheater, !isContentLoading {
                        actionBar
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(AppTheme.divider(scheme)).frame(height: 0.5)
                            }
                    }
                }
                .background(isTheater ? Color.clear : AppTheme.background(scheme))
                .zIndex(1)
            }
        }
    }

    private func theaterPlayerSize(in size: CGSize) -> CGSize {
        let width = max(1, size.width)
        let fittedHeight = width * 9 / 16
        if fittedHeight <= size.height {
            return CGSize(width: width, height: fittedHeight)
        }
        let height = max(1, size.height)
        return CGSize(width: height * 16 / 9, height: height)
    }

    private var displayTitle: String {
        if model.detailBVID == video.bvid, let title = model.detail?.title, !title.isEmpty {
            return title
        }
        return video.title
    }

    private var isContentLoading: Bool {
        guard model.detailError == nil else { return false }
        return model.isLoadingDetail
            || (model.detail == nil && model.detailBVID == video.bvid)
    }

    private var actionBar: some View {
        HStack(alignment: .center, spacing: 12) {
            channelView

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                ActionPill(
                    systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    title: "点赞",
                    countText: likeCountText,
                    isActive: liked
                ) {
                    Task { await model.toggleLike() }
                }

                ActionPill(
                    systemName: "circlebadge.2",
                    title: "投币",
                    countText: coinCountText,
                    isActive: (model.relation?.coin ?? 0) > 0
                ) {
                    Task { await model.addCoin(multiply: 1) }
                }

                favoriteMenu

                downloadPill

                ActionPill(
                    systemName: isSaved ? "bookmark.fill" : "bookmark",
                    title: isSaved ? "已添加" : "稍后再看",
                    isActive: isSaved
                ) {
                    Task { await model.addToWatchLater() }
                }

                ActionPill(systemName: "square.and.arrow.up", title: "分享") {
                    share()
                }

                moreMenu
            }
            .fixedSize()
        }
    }

    private var downloadPill: some View {
        let job = model.downloadJob(for: video)
        return ActionPill(
            systemName: job?.isCompleted == true ? "arrow.down.circle.fill" : "arrow.down.circle",
            title: downloadTitle(job),
            isActive: job != nil
        ) {
            if let job {
                if job.isCompleted {
                    model.openDownload(job)
                } else if job.isPaused || job.isFailed {
                    Task { await model.resumeDownload(job) }
                } else {
                    model.selectSection(.downloads)
                }
            } else {
                Task { await model.startDownload(for: video, detail: model.detail) }
            }
        }
    }

    private func downloadTitle(_ job: DownloadJob?) -> String {
        guard let job else { return "下载" }
        if job.isCompleted { return "已下载" }
        if job.isFailed { return "重试下载" }
        if job.isPaused { return "继续下载" }
        return "下载中 \(Int(job.progress * 100))%"
    }

    private var channelView: some View {
        HStack(spacing: 12) {
            Button {
                if let mid = ownerMID {
                    model.openUP(mid: mid, name: ownerName, avatarURL: ownerFaceURL)
                } else if let url = ownerSpaceURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 11) {
                    AvatarView(url: ownerFaceURL, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ownerName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("UP 主")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .disabled(ownerSpaceURL == nil)
            .contextMenu {
                if let url = ownerSpaceURL {
                    Button("在浏览器中打开") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Button {
                Task { await model.toggleFollow() }
            } label: {
                Text(isFollowing ? "已关注" : "关注")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isFollowing ? AppTheme.text(scheme) : AppTheme.selectedText(scheme))
                    .padding(.horizontal, 17)
                    .frame(height: 36)
                    .background(
                        isFollowing ? AppTheme.chip(scheme) : AppTheme.selected(scheme),
                        in: Capsule()
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var descriptionCard: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isDescriptionExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if viewCount > 0 {
                        Text("\(viewText)次观看")
                    }
                    if !publishedAgo.isEmpty {
                        if viewCount > 0 { Text("·") }
                        Text(publishedAgo)
                    }
                    if danmakuCount > 0 {
                        Text("·")
                        Text("\(danmakuText)条弹幕")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))

                Text(descriptionText.isEmpty ? "暂无简介" : descriptionText)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(isDescriptionExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if descriptionText.count > 90 {
                    Text(isDescriptionExpanded ? "收起" : "展开")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.surface(scheme),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tagStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.videoTags, id: \.self) { tag in
                    TagChip(title: tag, isSelected: false) {
                        model.closeVideo()
                        model.searchTerm = tag
                        Task { await model.submitSearch() }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func aiSummaryCard(_ conclusion: AIConclusionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                Text("AI 总结")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                Text("仅供参考")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }

            if let summary = conclusion.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .foregroundStyle(AppTheme.text(scheme))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let outline = conclusion.outline, !outline.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(outline.enumerated()), id: \.offset) { _, section in
                        if let title = section.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !title.isEmpty {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.secondary(scheme))
                        }
                        ForEach(Array((section.partOutline ?? []).enumerated()), id: \.offset) { _, part in
                            HStack(alignment: .top, spacing: 8) {
                                if let timestamp = part.timestamp, timestamp > 0 {
                                    Text(timestampText(timestamp))
                                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                                        .foregroundStyle(AppTheme.brand)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                if let content = part.content, !content.isEmpty {
                                    Text(content)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.text(scheme))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.surface(scheme),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func timestampText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private var moreMenu: some View {        Menu {
            Button("一键三连") {
                Task { await model.tripleVideo() }
            }
            Toggle("自动连播", isOn: $autoplayNext)
            Divider()
            Button("在浏览器中打开") {
                NSWorkspace.shared.open(video.pageURL)
            }
            if let url = ownerSpaceURL {
                Button("打开 UP 主空间") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("复制链接") {
                share()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .frame(width: 36, height: 36)
                .background(AppTheme.chip(scheme), in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var favoriteMenu: some View {
        Menu {
            if model.favoriteFolders.isEmpty {
                Button("加载收藏夹…") {
                    Task { await model.loadPlaylists(force: true) }
                }
            } else {
                ForEach(model.favoriteFolders) { folder in
                    Button(folder.title) {
                        Task { await model.addToFavorite(folderID: folder.id) }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isFavorited ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                Text(isFavorited ? "已收藏" : "收藏")
                    .font(.system(size: 13, weight: .semibold))
                Text(favoriteCountText)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isFavorited ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                isFavorited ? AppTheme.selected(scheme) : AppTheme.chip(scheme),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .task {
            if model.hasAccount, model.favoriteFolders.isEmpty {
                await model.loadPlaylists()
            }
        }
    }

    private var toast: some View {
        Group {
            if let message = model.toastMessage {
                GlassSurface {
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                }
                .padding(.bottom, 26)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var liked: Bool { model.relation?.like == true }
    private var isFollowing: Bool { model.relation?.attention == true }
    private var isFavorited: Bool { model.relation?.favorite == true }
    private var isSaved: Bool { model.watchLaterVideos.contains(video.bvid) }
    private var ownerName: String { model.detail?.owner?.name ?? video.ownerName }
    private var ownerFaceURL: URL? {
        MediaURL.normalize(model.detail?.owner?.face) ?? video.ownerFaceURL
    }
    private var ownerSpaceURL: URL? {
        let mid = model.detail?.owner?.mid ?? video.ownerMid
        guard let mid, mid > 0 else { return nil }
        return URL(string: "https://space.bilibili.com/\(mid)")
    }
    private var ownerMID: Int64? {
        let mid = model.detail?.owner?.mid ?? video.ownerMid
        guard let mid, mid > 0 else { return nil }
        return mid
    }
    private var viewCount: Int { model.detail?.stat?.view ?? video.viewCount }
    private var danmakuCount: Int { model.detail?.stat?.danmaku ?? video.danmakuCount }
    private var viewText: String { formatCount(viewCount) }
    private var danmakuText: String { formatCount(danmakuCount) }
    private var likeCountText: String {
        formatCount(model.detail?.stat?.like ?? video.likeCount)
    }
    private var coinCountText: String {
        formatCount(model.detail?.stat?.coin ?? 0)
    }
    private var favoriteCountText: String {
        formatCount(model.detail?.stat?.favorite ?? 0)
    }
    private var publishedAgo: String {
        model.detail?.publishedAgoText ?? video.publishedAgoText
    }
    private var descriptionText: String {
        let text = model.detail?.desc ?? video.description
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func share() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(video.pageURL.absoluteString, forType: .string)
        model.showToast("链接已复制")
    }

    private func formatCount(_ count: Int) -> String {
        let value = Double(count)
        if value >= 100_000_000 {
            return String(format: "%.1f亿", value / 100_000_000)
        }
        if value >= 10_000 {
            return String(format: "%.1f万", value / 10_000)
        }
        return "\(count)"
    }
}

private struct CommentsSectionView: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    @State private var replyTarget: VideoComment?
    @State private var replyRootID: Int64?
    @State private var isEmojiPickerPresented = false
    @State private var isExpanded = false
    @FocusState private var isComposerFocused: Bool

    private static let commentEmojis = [
        "😀", "😄", "😂", "🤣", "🥰", "😍", "😊", "😉",
        "😎", "🤔", "😅", "😭", "😤", "😡", "🥺", "😴",
        "🤯", "👍", "👏", "🙏", "💪", "🎉", "❤️", "🔥",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("\(formatCount(model.commentTotal)) 条评论")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                if model.isLoadingComments {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Menu {
                    Button("热门评论") {
                        Task { await model.setCommentSort(0) }
                    }
                    Button("最新评论") {
                        Task { await model.setCommentSort(1) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text(model.commentSort == 0 ? "热门" : "最新")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.text(scheme))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(AppTheme.chip(scheme), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            composer

            if let error = model.commentsError {
                HStack(spacing: 10) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Button("重试") {
                        Task { await model.reloadComments() }
                    }
                    .buttonStyle(.link)
                }
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                if model.comments.isEmpty && !model.isLoadingComments {
                    Text("还没有评论，来抢沙发吧。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .padding(.vertical, 18)
                } else {
                    ForEach(isExpanded ? model.comments : Array(model.comments.prefix(3))) { comment in
                        CommentRowView(
                            comment: comment,
                            oid: model.detail?.aid ?? 0,
                            type: "1"
                        ) { target, rootID in
                            beginReply(to: target, rootID: rootID)
                        }
                        .id("thread-\(comment.id)")
                        Rectangle()
                            .fill(AppTheme.divider(scheme))
                            .frame(height: 1)
                            .padding(.leading, 48)
                    }
                }

                if !isExpanded, model.comments.count > 3 {
                    expandCommentsButton
                } else {
                    if !model.hasAccount, model.comments.count < model.commentTotal {
                        Button {
                            model.presentLogin()
                        } label: {
                            Text("登录查看更多评论")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.text(scheme))
                                .padding(.horizontal, 16)
                                .frame(height: 34)
                                .background(AppTheme.chip(scheme), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                    } else if model.hasAccount, model.comments.count < model.commentTotal {
                        InfiniteScrollFooter(
                            isLoading: model.isLoadingComments,
                            hasMore: model.comments.count < model.commentTotal,
                            failed: model.commentsError != nil
                        ) {
                            Task { await model.loadMoreComments() }
                        }
                    }

                    if isExpanded, model.comments.count > 3 {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isExpanded = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("收起评论")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(AppTheme.chip(scheme), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .onChange(of: video.bvid) { _, _ in
            isExpanded = false
        }
    }

    private var expandCommentsButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 5) {
                Text("展开更多评论")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppTheme.text(scheme))
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(AppTheme.chip(scheme), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var composer: some View {
        if model.hasAccount {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: model.profile?.avatarURL ?? model.activeAccount?.avatarURL, size: 36)

                VStack(alignment: .leading, spacing: 8) {
                    if let replyTarget {
                        HStack(spacing: 6) {
                            Text("回复 @\(replyTarget.author)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .lineLimit(1)
                            Button {
                                self.replyTarget = nil
                                replyRootID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.tertiary(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField(replyTarget.map { "回复 @\($0.author)…" } ?? "添加评论…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isComposerFocused)
                        .padding(10)
                        .background(
                            AppTheme.surface(scheme),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )

                    HStack(spacing: 8) {
                        Button {
                            isEmojiPickerPresented.toggle()
                        } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .frame(width: 30, height: 30)
                                .background(AppTheme.chip(scheme), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("插入表情")
                        .popover(isPresented: $isEmojiPickerPresented, arrowEdge: .bottom) {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 8),
                                spacing: 6
                            ) {
                                ForEach(Self.commentEmojis, id: \.self) { emoji in
                                    Button {
                                        draft += emoji
                                        isEmojiPickerPresented = false
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 18))
                                            .frame(width: 30, height: 30)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                        }

                        Spacer()
                        if !draft.isEmpty {
                            Button("取消") {
                                draft = ""
                                isComposerFocused = false
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                        }
                        Button {
                            let text = draft
                            let target = replyTarget
                            let rootID = replyRootID
                            Task {
                                if await model.postComment(text, replyTo: target, rootID: rootID) {
                                    draft = ""
                                    replyTarget = nil
                                    replyRootID = nil
                                    isComposerFocused = false
                                }
                            }
                        } label: {
                            Text(model.isPostingComment ? "发布中…" : (replyTarget == nil ? "评论" : "回复"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.selectedText(scheme))
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .background(AppTheme.selected(scheme), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isPostingComment)
                    }
                }
            }
        } else {
            Button {
                model.presentLogin()
            } label: {
                HStack(spacing: 12) {
                    AvatarView(url: nil, size: 36)
                    Text("登录后参与评论")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Spacer()
                    Text("登录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.selectedText(scheme))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(AppTheme.selected(scheme), in: Capsule())
                }
                .padding(10)
                .background(
                    AppTheme.surface(scheme),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func beginReply(to comment: VideoComment, rootID: Int64?) {
        guard model.hasAccount else {
            model.presentLogin()
            return
        }
        replyTarget = comment
        replyRootID = rootID
        isComposerFocused = true
    }

    private func formatCount(_ count: Int) -> String {
        let value = Double(count)
        if value >= 100_000_000 {
            return String(format: "%.1f亿", value / 100_000_000)
        }
        if value >= 10_000 {
            return String(format: "%.1f万", value / 10_000)
        }
        return "\(count)"
    }
}

private struct CommentRowView: View {
    let comment: VideoComment
    let oid: Int64
    let type: String
    let onReply: (VideoComment, Int64?) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isExpanded = false

    private let reportReasons: [(title: String, reason: Int)] = [
        ("垃圾广告", 1),
        ("色情低俗", 2),
        ("人身攻击", 3),
        ("引战", 4),
        ("政治敏感", 5),
        ("违法信息", 6),
        ("其他", 7),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: comment.avatarURL, size: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(comment.author)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)
                    Text(comment.timeText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }

                Text(comment.message)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(isExpanded ? nil : 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if comment.message.count > 170 {
                    Button(isExpanded ? "收起" : "展开") {
                        withAnimation(.easeOut(duration: 0.14)) {
                            isExpanded.toggle()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                }

                actionRow

                CommentThreadView(
                    root: comment,
                    oid: oid,
                    type: type,
                    onReply: onReply
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button {
                Task { await model.toggleCommentLike(comment) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: comment.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(comment.likeCount > 0 || comment.isLiked ? comment.likeText : "赞")
                        .font(.system(size: 11))
                        .monospacedDigit()
                }
                .foregroundStyle(comment.isLiked ? AppTheme.brand : AppTheme.secondary(scheme))
            }
            .buttonStyle(.plain)

            Button {
                onReply(comment, nil)
            } label: {
                Text("回复")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(reportReasons, id: \.reason) { item in
                    Button("举报 · \(item.title)") {
                        Task { await model.reportComment(comment, reason: item.reason) }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(width: 18, height: 16)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

private struct RelatedRailView: View {
    let video: VideoItem
    var showsSkeleton = false

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接下来播放")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))

            if showsSkeleton || (model.isLoadingRelated && model.relatedVideos.isEmpty) {
                ForEach(0..<5, id: \.self) { _ in
                    RelatedVideoSkeleton()
                }
            } else if model.relatedVideos.isEmpty {
                Text("暂无相关推荐")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .padding(.vertical, 20)
            } else {
                ForEach(model.relatedVideos) { item in
                    Button {
                        model.openVideo(item)
                    } label: {
                        RelatedVideoRow(video: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RelatedVideoRow: View {
    let video: VideoItem

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VideoThumbnail(
                url: video.coverURL,
                durationText: video.durationText,
                cornerRadius: 8,
                transitionID: video.bvid
            )
                .frame(width: 164)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(video.ownerName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .background(
            isHovering ? AppTheme.hover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var metadata: String {
        var parts: [String] = []
        if video.viewCount > 0 {
            parts.append("\(video.viewText)次观看")
        }
        if !video.publishedAgoText.isEmpty {
            parts.append(video.publishedAgoText)
        }
        return parts.joined(separator: " · ")
    }
}

struct RelatedVideoSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .frame(width: 164)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBar(height: 12)
                SkeletonBar(width: 110, height: 10)
                SkeletonBar(width: 80, height: 10)
            }
        }
        .padding(6)
        .skeletonPulse()
    }
}
