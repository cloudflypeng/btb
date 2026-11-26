import AppKit
import SwiftUI

struct DynamicFeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if !model.hasAccount {
                    loginState
                } else if model.isLoadingDynamic && model.dynamicCards.isEmpty {
                    ForEach(0..<4, id: \.self) { _ in
                        DynamicCardSkeleton()
                    }
                } else if let error = model.dynamicError, model.dynamicCards.isEmpty {
                    ErrorBanner(text: error) {
                        Task { await model.loadDynamicFeed(reset: true) }
                    }
                } else if model.dynamicCards.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.dynamicCards) { card in
                            DynamicCardView(card: card)
                        }
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingDynamic,
                        hasMore: model.dynamicHasMore,
                        failed: model.dynamicError != nil
                    ) {
                        Task { await model.loadMoreDynamic() }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .task {
            if !model.dynamicLoaded || model.dynamicCards.isEmpty {
                await model.loadDynamicFeed(reset: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("动态")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                Spacer()

                Button {
                    Task { await model.loadDynamicFeed(reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 30, height: 30)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingDynamic || !model.hasAccount)
                .help("刷新动态")
            }

            HStack(spacing: 8) {
                ForEach(DynamicFeedType.allCases) { type in
                    BtbPill(title: type.title, isSelected: model.dynamicFeedType == type) {
                        Task { await model.setDynamicFeedType(type) }
                    }
                }
            }
        }
    }

    private var loginState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("登录后查看关注动态")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Button {
                model.presentLogin()
            } label: {
                Text("登录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.selectedText(scheme))
                    .padding(.horizontal, 22)
                    .frame(height: 34)
                    .background(AppTheme.selected(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("还没有新动态")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text("关注 UP 主后，最新内容会出现在这里。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct DynamicDetailView: View {
    let card: DynamicCard

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("动态详情")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(webURL)
                    } label: {
                        Label("在浏览器中打开", systemImage: "safari")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                DynamicCardView(card: card, opensDetail: false, isDetail: true)

                DynamicCommentsSection(card: card)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
    }

    private var webURL: URL {
        URL(string: "https://t.bilibili.com/\(card.id)")!
    }
}

struct DynamicCardView: View {
    let card: DynamicCard
    var opensDetail = true
    var isDetail = false

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !card.text.isEmpty {
                Text(card.text)
                    .font(.system(size: isDetail ? 14.5 : 13.5))
                    .lineSpacing(5)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(isDetail ? nil : 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            attachment(card.attachment)

            if let orig = card.orig {
                DynamicOriginalView(original: orig)
            }

            actionBar
        }
        .padding(isDetail ? 18 : 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovering && opensDetail ? AppTheme.surfaceHover(scheme) : AppTheme.surface(scheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            guard opensDetail else { return }
            isHovering = hovering
        }
        .onTapGesture {
            guard opensDetail else { return }
            model.openDynamic(card)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            Button {
                if let mid = card.author.mid {
                    model.openUP(mid: mid, name: card.author.name, avatarURL: card.author.avatarURL)
                }
            } label: {
                AvatarView(url: card.author.avatarURL, size: isDetail ? 44 : 38)
            }
            .buttonStyle(.plain)
            .disabled(card.author.mid == nil)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.author.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)
                    if card.author.isTop {
                        Text("置顶")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    if !card.author.pubAction.isEmpty {
                        Text(card.author.pubAction)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    Text(card.author.pubTime)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }

            Spacer(minLength: 8)

            Menu {
                Button("复制链接") {
                    copyLink()
                }
                Button("在浏览器中打开") {
                    NSWorkspace.shared.open(webURL)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    @ViewBuilder
    private func attachment(_ attachment: DynamicAttachment) -> some View {
        if let video = attachment.video {
            videoCard(video)
        } else if !attachment.pictures.isEmpty {
            DynamicImageGrid(pictures: attachment.pictures, isDetail: isDetail) {
                guard opensDetail else { return }
                model.openDynamic(card)
            }
        } else if let pgc = attachment.pgc {
            pgcCard(pgc)
        } else if let live = attachment.live {
            liveCard(live)
        } else if let article = attachment.article {
            articleCard(article)
        }
    }

    private func videoCard(_ video: DynamicVideoAttachment) -> some View {
        Button {
            model.openVideo(videoItem(from: video))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VideoThumbnail(
                    url: video.coverURL,
                    durationText: video.durationText,
                    cornerRadius: 8,
                    transitionID: video.bvid
                )
                .frame(width: isDetail ? 240 : 190)

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title.isEmpty ? "视频" : video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !video.desc.isEmpty {
                        Text(video.desc)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        if !video.playText.isEmpty {
                            Label(video.playText, systemImage: "play.rectangle")
                        }
                        Text(card.author.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pgcCard(_ pgc: DynamicPGCAttachment) -> some View {
        Button {
            if let url = pgc.jumpURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RemoteImage(url: pgc.coverURL)
                    .frame(width: 96, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .background(AppTheme.chip(scheme))

                VStack(alignment: .leading, spacing: 7) {
                    if !pgc.badge.isEmpty {
                        Text(pgc.badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    Text(pgc.title.isEmpty ? "番剧" : pgc.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Text("番剧 · 点击在浏览器中打开")
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func liveCard(_ live: DynamicLiveAttachment) -> some View {
        Button {
            NSWorkspace.shared.open(URL(string: "https://live.bilibili.com/\(live.roomID)")!)
        } label: {
            HStack(spacing: 12) {
                RemoteImage(url: live.coverURL)
                    .frame(width: 190, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .background(AppTheme.chip(scheme))
                    .overlay(alignment: .topLeading) {
                        Text("直播")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(AppTheme.brand, in: Capsule())
                            .padding(7)
                    }
                VStack(alignment: .leading, spacing: 6) {
                    Text(live.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !live.areaName.isEmpty {
                        Text(live.areaName)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    Text("点击在浏览器中打开直播间")
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func articleCard(_ article: DynamicArticleAttachment) -> some View {
        Button {
            if let url = article.jumpURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let cover = article.coverURL {
                    RemoteImage(url: cover)
                        .frame(width: 128, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title.isEmpty ? "专栏" : article.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        HStack(spacing: 22) {
            DynamicActionButton(
                systemName: card.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                title: formatCount(card.likeCount),
                isActive: card.isLiked
            ) {
                Task { await model.toggleDynamicLike(card) }
            }

            DynamicActionButton(
                systemName: "bubble.right",
                title: formatCount(card.commentCount)
            ) {
                if opensDetail {
                    model.openDynamic(card)
                } else {
                    NSWorkspace.shared.open(webURL)
                }
            }

            DynamicActionButton(
                systemName: "arrow.2.squarepath",
                title: formatCount(card.forwardCount)
            ) {
                copyLink()
            }

            Spacer()

            Button {
                copyLink()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("复制链接")
        }
        .padding(.top, 2)
    }

    private var webURL: URL {
        URL(string: "https://t.bilibili.com/\(card.id)")!
    }

    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(webURL.absoluteString, forType: .string)
        model.showToast("链接已复制")
    }

    private func videoItem(from video: DynamicVideoAttachment) -> VideoItem {
        VideoItem(
            dynamicVideo: video,
            ownerName: card.author.name,
            ownerFaceURL: card.author.avatarURL,
            ownerMid: card.author.mid
        )
    }
}

private struct DynamicCommentsSection: View {
    let card: DynamicCard

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    @State private var replyTarget: VideoComment?
    @State private var replyRootID: Int64?
    @FocusState private var isComposerFocused: Bool

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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text("评论 \(formatCount(model.dynamicCommentTotal))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if model.isLoadingDynamicComments {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            composer

            if let error = model.dynamicCommentsError {
                HStack(spacing: 10) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Button("重试") {
                        Task { await model.loadDynamicComments(for: card, reset: true) }
                    }
                    .buttonStyle(.link)
                }
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                if model.dynamicComments.isEmpty && !model.isLoadingDynamicComments {
                    Text("还没有评论，来抢沙发吧。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .padding(.vertical, 18)
                } else {
                    ForEach(model.dynamicComments) { comment in
                        row(comment)
                        Rectangle()
                            .fill(AppTheme.divider(scheme))
                            .frame(height: 1)
                            .padding(.leading, 48)
                    }
                }

                if model.dynamicComments.count < model.dynamicCommentTotal {
                    InfiniteScrollFooter(
                        isLoading: model.isLoadingDynamicComments,
                        hasMore: model.dynamicComments.count < model.dynamicCommentTotal,
                        failed: model.dynamicCommentsError != nil
                    ) {
                        Task { await model.loadDynamicComments(for: card) }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: card.id) {
            await model.loadDynamicComments(for: card, reset: true)
        }
    }

    @ViewBuilder
    private var composer: some View {
        if model.hasAccount {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: model.profile?.avatarURL ?? model.activeAccount?.avatarURL, size: 34)

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
                            AppTheme.chip(scheme),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )

                    HStack(spacing: 8) {
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
                                if await model.postDynamicComment(
                                    text,
                                    card: card,
                                    replyTo: target,
                                    rootID: rootID
                                ) {
                                    draft = ""
                                    replyTarget = nil
                                    replyRootID = nil
                                    isComposerFocused = false
                                }
                            }
                        } label: {
                            Text(model.isPostingDynamicComment ? "发布中…" : (replyTarget == nil ? "评论" : "回复"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.selectedText(scheme))
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .background(AppTheme.selected(scheme), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.isPostingDynamicComment
                        )
                    }
                }
            }
        } else {
            Button {
                model.presentLogin()
            } label: {
                HStack(spacing: 12) {
                    AvatarView(url: nil, size: 34)
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
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ comment: VideoComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: comment.avatarURL, size: 34)

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
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 16) {
                    Button {
                        Task { await model.toggleDynamicCommentLike(comment, card: card) }
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
                        beginReply(to: comment, rootID: nil)
                    } label: {
                        Text("回复")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                    .buttonStyle(.plain)

                    Menu {
                        ForEach(reportReasons, id: \.reason) { item in
                            Button("举报 · \(item.title)") {
                                Task {
                                    await model.reportDynamicComment(comment, card: card, reason: item.reason)
                                }
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

                CommentThreadView(
                    root: comment,
                    oid: Int64(card.commentID) ?? 0,
                    type: String(card.commentType),
                    onReply: { target, rootID in
                        beginReply(to: target, rootID: rootID)
                    }
                )
            }
        }
        .padding(.vertical, 8)
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
}

private struct DynamicOriginalView: View {
    let original: DynamicOriginal

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                AvatarView(url: original.author.avatarURL, size: 20)
                Text(original.author.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                if !original.author.pubTime.isEmpty {
                    Text(original.author.pubTime)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }

            if !original.text.isEmpty {
                Text(original.text)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let video = original.attachment.video {
                HStack(spacing: 9) {
                    VideoThumbnail(
                        url: video.coverURL,
                        durationText: video.durationText,
                        cornerRadius: 6,
                        transitionID: video.bvid
                    )
                    .frame(width: 142)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(2)
                        if !video.playText.isEmpty {
                            Text("\(video.playText) 播放")
                                .font(.system(size: 10.5))
                                .foregroundStyle(AppTheme.tertiary(scheme))
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else if !original.attachment.pictures.isEmpty {
                DynamicImageGrid(pictures: original.attachment.pictures, isDetail: false) {}
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.chip(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DynamicImageGrid: View {
    let pictures: [DynamicPicture]
    var isDetail: Bool
    let onTap: () -> Void

    private var columnCount: Int {
        switch pictures.count {
        case 1: return 1
        case 2, 4: return 2
        default: return 3
        }
    }

    var body: some View {
        Group {
            if pictures.count == 1, let picture = pictures.first {
                Color.clear
                    .frame(height: isDetail ? 340 : 280)
                    .overlay {
                        RemoteImage(url: picture.url)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture(perform: onTap)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount),
                    spacing: 6
                ) {
                    ForEach(Array(pictures.prefix(9))) { picture in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                RemoteImage(url: picture.url)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .onTapGesture(perform: onTap)
                    }
                }
            }
        }
    }
}

private struct DynamicActionButton: View {
    let systemName: String
    let title: String
    var isActive = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
            .foregroundStyle(isActive ? AppTheme.brand : AppTheme.secondary(scheme))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DynamicCardSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SkeletonCircle(size: 38)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonCapsule(width: 110, height: 11)
                    SkeletonCapsule(width: 70, height: 9)
                }
                Spacer()
            }
            SkeletonBar(height: 12)
            SkeletonBar(width: 320, height: 12)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .frame(height: 120)
        }
        .padding(15)
        .background(AppTheme.surface(scheme).opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .skeletonPulse()
    }
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
