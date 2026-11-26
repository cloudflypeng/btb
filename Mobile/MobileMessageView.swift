import SwiftUI
import UIKit

struct MobileMessageView: View {
    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @State private var selectedSeason: MobileAnimeRoute?
    @State private var isResolvingVideo = false

    private static let olderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedSeason) { route in
            MobileAnimeSeasonView(seasonID: route.seasonID)
        }
        .task {
            await model.prepareMessages()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("消息")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            if let unread = model.messageUnread?.total, unread > 0 {
                Text("\(unread) 条未读")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.brand)
            }
            Spacer()
            Button {
                Task { await model.refreshMessages() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!model.hasAccount)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MessageTab.allCases) { tab in
                    MobileMessageTabChip(
                        title: tab.title,
                        icon: tab.icon,
                        unread: model.messageUnread?.count(for: tab) ?? 0,
                        isSelected: model.messageTab == tab
                    ) {
                        guard model.messageTab != tab else { return }
                        Task { await model.selectMessageTab(tab) }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 9)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if !model.hasAccount {
                loginState
            } else {
                VStack(spacing: 0) {
                    switch model.messageTab {
                    case .replies:
                        repliesContent
                    case .ats:
                        atsContent
                    case .likes:
                        likesContent
                    case .system:
                        systemContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.refreshMessages()
        }
    }

    private var loginState: some View {
        VStack(spacing: 14) {
            MobileEmptyState(
                icon: "person.crop.circle.badge.plus",
                title: "登录后查看消息",
                message: "回复、@、点赞和系统通知都会显示在这里"
            )

            Button {
                model.presentLogin()
            } label: {
                Text("扫码登录")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(height: 42)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 70)
        }
    }

    @ViewBuilder
    private var repliesContent: some View {
        let feed = model.messageReplies
        if let error = feed.error {
            MobileErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if feed.isLoading && feed.items.isEmpty {
            loadingHint
        } else if feed.items.isEmpty {
            if feed.error == nil {
                MobileEmptyState(
                    icon: MessageTab.replies.icon,
                    title: MessageTab.replies.emptyTitle,
                    message: MessageTab.replies.emptyMessage
                )
            }
        } else {
            ForEach(feed.items) { entry in
                replyRow(entry)
            }
            footer(
                isLoading: feed.isLoading || feed.isLoadingMore,
                hasMore: feed.hasMore,
                failed: feed.failed,
                endText: "没有更多回复了"
            )
        }
    }

    @ViewBuilder
    private var atsContent: some View {
        let feed = model.messageAts
        if let error = feed.error {
            MobileErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if feed.isLoading && feed.items.isEmpty {
            loadingHint
        } else if feed.items.isEmpty {
            if feed.error == nil {
                MobileEmptyState(
                    icon: MessageTab.ats.icon,
                    title: MessageTab.ats.emptyTitle,
                    message: MessageTab.ats.emptyMessage
                )
            }
        } else {
            ForEach(feed.items) { entry in
                atRow(entry)
            }
            footer(
                isLoading: feed.isLoading || feed.isLoadingMore,
                hasMore: feed.hasMore,
                failed: feed.failed,
                endText: "没有更多 @ 消息了"
            )
        }
    }

    @ViewBuilder
    private var likesContent: some View {
        let feed = model.messageLikes
        if let error = feed.error {
            MobileErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if feed.isLoading && feed.items.isEmpty {
            loadingHint
        } else if feed.items.isEmpty {
            if feed.error == nil {
                MobileEmptyState(
                    icon: MessageTab.likes.icon,
                    title: MessageTab.likes.emptyTitle,
                    message: MessageTab.likes.emptyMessage
                )
            }
        } else {
            ForEach(feed.items) { entry in
                likeRow(entry)
            }
            footer(
                isLoading: feed.isLoading || feed.isLoadingMore,
                hasMore: feed.hasMore,
                failed: feed.failed,
                endText: "没有更多点赞了"
            )
        }
    }

    @ViewBuilder
    private var systemContent: some View {
        let feed = model.messageSystem
        if let error = feed.error {
            MobileErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if feed.isLoading && feed.items.isEmpty {
            loadingHint
        } else if feed.items.isEmpty {
            if feed.error == nil {
                MobileEmptyState(
                    icon: MessageTab.system.icon,
                    title: MessageTab.system.emptyTitle,
                    message: MessageTab.system.emptyMessage
                )
            }
        } else {
            ForEach(feed.items) { message in
                systemRow(message)
            }
            footer(
                isLoading: feed.isLoading || feed.isLoadingMore,
                hasMore: feed.hasMore,
                failed: feed.failed,
                endText: "没有更多通知了"
            )
        }
    }

    private var loadingHint: some View {
        ProgressView()
            .tint(AppTheme.brand)
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
    }

    private func footer(isLoading: Bool, hasMore: Bool, failed: Bool, endText: String) -> some View {
        InfiniteScrollFooter(
            isLoading: isLoading,
            hasMore: hasMore,
            failed: failed,
            endText: endText
        ) {
            Task { await model.loadMoreMessages() }
        }
    }

    private func replyRow(_ entry: MessageReplyEntry) -> some View {
        let item = entry.item
        return messageCard(
            unread: isUnread(entry.replyTime, lastViewAt: model.messageReplies.lastViewAt),
            destination: item?.destination
        ) {
            HStack(alignment: .top, spacing: 11) {
                AvatarView(url: entry.user?.avatarURL, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(entry.user?.displayName ?? "B站用户")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("回复了你的\(item?.businessLabel ?? "评论")")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(relativeTime(entry.replyTime))
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    let content = item?.displayContent ?? ""
                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("对方回复了你的内容")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }

                    let snippet = item?.sourceSnippet ?? ""
                    if !snippet.isEmpty {
                        sourceChip(snippet)
                    }

                    if let imageURL = item?.imageURL {
                        RemoteImage(url: imageURL)
                            .frame(width: 112, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private func atRow(_ entry: MessageAtEntry) -> some View {
        let item = entry.item
        return messageCard(
            unread: isUnread(entry.atTime, lastViewAt: model.messageAts.lastViewAt),
            destination: item?.destination
        ) {
            HStack(alignment: .top, spacing: 11) {
                AvatarView(url: entry.user?.avatarURL, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(entry.user?.displayName ?? "B站用户")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("在\(item?.businessLabel ?? "内容")中提到了你")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(relativeTime(entry.atTime))
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    let content = item?.displayContent ?? ""
                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let snippet = item?.sourceSnippet ?? ""
                    if !snippet.isEmpty {
                        sourceChip(snippet)
                    }
                }
            }
        }
    }

    private func likeRow(_ entry: MessageLikeEntry) -> some View {
        let item = entry.item
        return messageCard(
            unread: isUnread(entry.likeTime, lastViewAt: model.messageLikes.lastViewAt),
            destination: item?.destination
        ) {
            HStack(alignment: .top, spacing: 11) {
                AvatarView(url: entry.primaryUser?.avatarURL, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(likeSummary(entry))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("赞了你的\(item?.businessLabel ?? "内容")")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(relativeTime(entry.likeTime))
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    let content = item?.displayContent ?? ""
                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func systemRow(_ message: SystemMessage) -> some View {
        let destination = message.webURL.map { MessageDestination.external($0) }
        return messageCard(unread: false, destination: destination) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                    if let cover = message.coverURL {
                        AsyncImage(url: cover) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color.clear
                            }
                        }
                        .padding(5)
                    }
                }
                .frame(width: 40, height: 40)
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(message.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "系统通知")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        if message.isStation == 1 {
                            Text("站内信")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .padding(.horizontal, 6)
                                .frame(height: 16)
                                .background(AppTheme.chip(scheme), in: Capsule())
                        }
                        Spacer(minLength: 6)
                        Text(systemTime(message.timeAt))
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    let body = message.bodyText
                    if !body.isEmpty {
                        Text(body)
                            .font(.system(size: 12.5))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func messageCard<Content: View>(
        unread: Bool,
        destination: MessageDestination?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let card = HStack(alignment: .top, spacing: 8) {
            content()
            Spacer(minLength: 2)
            VStack(spacing: 8) {
                if unread {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 7, height: 7)
                }
                if let destination {
                    Image(systemName: destination.isExternalLink ? "arrow.up.right" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.5)
                .padding(.leading, 51)
        }
        .contentShape(Rectangle())

        return Group {
            if let destination {
                Button {
                    open(destination)
                } label: {
                    card
                }
                .buttonStyle(.plain)
            } else {
                card
            }
        }
    }

    private func sourceChip(_ text: String) -> some View {
        Text("原内容：\(text)")
            .font(.system(size: 11.5))
            .foregroundStyle(AppTheme.tertiary(scheme))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func likeSummary(_ entry: MessageLikeEntry) -> String {
        let users = entry.users ?? []
        let names = users.prefix(3).map(\.displayName)
        guard !names.isEmpty else { return "有人" }
        var text = names.joined(separator: "、")
        if let count = entry.counts, count > names.count {
            text += " 等 \(count) 人"
        }
        return text
    }

    private func open(_ destination: MessageDestination) {
        switch destination {
        case .video(let bvid):
            router.open(VideoItem(bvid: bvid))
        case .videoAID(let aid):
            guard !isResolvingVideo else { return }
            isResolvingVideo = true
            Task {
                defer { isResolvingVideo = false }
                if let bvid = await model.resolveVideoBVID(aid: aid) {
                    router.open(VideoItem(bvid: bvid))
                } else {
                    model.showToast("无法打开视频")
                }
            }
        case .season(let seasonID):
            selectedSeason = MobileAnimeRoute(seasonID: seasonID)
        case .external(let url):
            UIApplication.shared.open(url)
        }
    }

    private func isUnread(_ timestamp: Int64?, lastViewAt: Int64) -> Bool {
        guard let timestamp, lastViewAt > 0 else { return false }
        return timestamp > lastViewAt
    }

    private func relativeTime(_ timestamp: Int64?) -> String {
        guard let timestamp, timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) 小时前" }
        if seconds < 86400 * 7 { return "\(Int(seconds / 86400)) 天前" }
        return Self.olderDateFormatter.string(from: date)
    }

    private func systemTime(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: text) {
            return relativeTime(Int64(date.timeIntervalSince1970))
        }
        return String(text.prefix(16))
    }
}

private struct MobileMessageTabChip: View {
    let title: String
    let icon: String
    let unread: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                if unread > 0 {
                    Text(unread > 99 ? "99+" : "\(unread)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(AppTheme.brand, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(
                isSelected ? AppTheme.selected(scheme) : AppTheme.chip(scheme),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension MessageDestination {
    var isExternalLink: Bool {
        if case .external = self { return true }
        return false
    }
}
