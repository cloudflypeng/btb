import SwiftUI

struct MessagesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private static let olderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .frame(maxWidth: 1040, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
        .task {
#if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BTB_MESSAGE_TAB"],
               let tab = MessageTab(rawValue: raw) {
                model.messageTab = tab
            }
#endif
            await model.prepareMessages()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SectionHeader(title: "消息", icon: "bell")

            HStack(spacing: 8) {
                ForEach(MessageTab.allCases) { tab in
                    let unread = model.messageUnread?.count(for: tab) ?? 0
                    BtbPill(
                        title: tab.title,
                        isSelected: model.messageTab == tab,
                        systemImage: tab.icon,
                        badge: unread > 0 ? (unread > 99 ? "99+" : "\(unread)") : nil
                    ) {
                        Task { await model.selectMessageTab(tab) }
                    }
                }
            }

            Spacer()

            if let unread = model.messageUnread?.total, unread > 0 {
                Text("\(unread) 条未读")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.brand)
            }

            Button {
                Task { await model.refreshMessages() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 30, height: 30)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .help("刷新消息")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasAccount {
            EmptyHint(
                icon: "person.crop.circle.badge.plus",
                title: "登录后查看消息",
                message: "登录后可查看回复、@、点赞和系统通知。"
            )
            .padding(.top, 60)
        } else {
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
    }

    @ViewBuilder
    private var repliesContent: some View {
        if let error = model.messageReplies.error {
            ErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if model.messageReplies.isLoading && model.messageReplies.items.isEmpty {
            loadingHint
        } else if model.messageReplies.items.isEmpty {
            if model.messageReplies.error == nil {
                EmptyHint(
                    icon: MessageTab.replies.icon,
                    title: MessageTab.replies.emptyTitle,
                    message: MessageTab.replies.emptyMessage
                )
                .padding(.top, 60)
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(model.messageReplies.items) { entry in
                    replyRow(entry)
                }
                messagesFooter(
                    isLoading: model.messageReplies.isLoading || model.messageReplies.isLoadingMore,
                    hasMore: model.messageReplies.hasMore,
                    failed: model.messageReplies.failed,
                    endText: "没有更多回复了"
                )
            }
        }
    }

    @ViewBuilder
    private var atsContent: some View {
        if let error = model.messageAts.error {
            ErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if model.messageAts.isLoading && model.messageAts.items.isEmpty {
            loadingHint
        } else if model.messageAts.items.isEmpty {
            if model.messageAts.error == nil {
                EmptyHint(
                    icon: MessageTab.ats.icon,
                    title: MessageTab.ats.emptyTitle,
                    message: MessageTab.ats.emptyMessage
                )
                .padding(.top, 60)
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(model.messageAts.items) { entry in
                    atRow(entry)
                }
                messagesFooter(
                    isLoading: model.messageAts.isLoading || model.messageAts.isLoadingMore,
                    hasMore: model.messageAts.hasMore,
                    failed: model.messageAts.failed,
                    endText: "没有更多 @ 消息了"
                )
            }
        }
    }

    @ViewBuilder
    private var likesContent: some View {
        if let error = model.messageLikes.error {
            ErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if model.messageLikes.isLoading && model.messageLikes.items.isEmpty {
            loadingHint
        } else if model.messageLikes.items.isEmpty {
            if model.messageLikes.error == nil {
                EmptyHint(
                    icon: MessageTab.likes.icon,
                    title: MessageTab.likes.emptyTitle,
                    message: MessageTab.likes.emptyMessage
                )
                .padding(.top, 60)
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(model.messageLikes.items) { entry in
                    likeRow(entry)
                }
                messagesFooter(
                    isLoading: model.messageLikes.isLoading || model.messageLikes.isLoadingMore,
                    hasMore: model.messageLikes.hasMore,
                    failed: model.messageLikes.failed,
                    endText: "没有更多点赞了"
                )
            }
        }
    }

    @ViewBuilder
    private var systemContent: some View {
        if let error = model.messageSystem.error {
            ErrorBanner(text: error) {
                Task { await model.refreshMessages() }
            }
        }
        if model.messageSystem.isLoading && model.messageSystem.items.isEmpty {
            loadingHint
        } else if model.messageSystem.items.isEmpty {
            if model.messageSystem.error == nil {
                EmptyHint(
                    icon: MessageTab.system.icon,
                    title: MessageTab.system.emptyTitle,
                    message: MessageTab.system.emptyMessage
                )
                .padding(.top, 60)
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(model.messageSystem.items) { message in
                    systemRow(message)
                }
                messagesFooter(
                    isLoading: model.messageSystem.isLoading || model.messageSystem.isLoadingMore,
                    hasMore: model.messageSystem.hasMore,
                    failed: model.messageSystem.failed,
                    endText: "没有更多通知了"
                )
            }
        }
    }

    private var loadingHint: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在加载消息…")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func messagesFooter(
        isLoading: Bool,
        hasMore: Bool,
        failed: Bool,
        endText: String
    ) -> some View {
        InfiniteScrollFooter(
            isLoading: isLoading,
            hasMore: hasMore,
            failed: failed,
            endText: endText
        ) {
            Task { await model.loadMoreMessages() }
        }
        .padding(.top, 4)
    }

    private func replyRow(_ entry: MessageReplyEntry) -> some View {
        let item = entry.item
        let destination = item?.destination
        let content = item?.displayContent ?? ""
        let snippet = item?.sourceSnippet ?? ""
        return messageCard(
            unread: isUnread(entry.replyTime, lastViewAt: model.messageReplies.lastViewAt),
            destination: destination
        ) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: entry.user?.avatarURL, size: 42)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(entry.user?.displayName ?? "B站用户")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("回复了你的\(item?.businessLabel ?? "评论")")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(relativeTime(entry.replyTime))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2.5)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("对方回复了你的内容")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }

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
        let destination = item?.destination
        let content = item?.displayContent ?? ""
        let snippet = item?.sourceSnippet ?? ""
        return messageCard(
            unread: isUnread(entry.atTime, lastViewAt: model.messageAts.lastViewAt),
            destination: destination
        ) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: entry.user?.avatarURL, size: 42)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(entry.user?.displayName ?? "B站用户")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("在\(item?.businessLabel ?? "内容")中提到了你")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(relativeTime(entry.atTime))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2.5)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !snippet.isEmpty {
                        sourceChip(snippet)
                    }
                }
            }
        }
    }

    private func likeRow(_ entry: MessageLikeEntry) -> some View {
        let item = entry.item
        let destination = item?.destination
        let content = item?.displayContent ?? ""
        return messageCard(
            unread: isUnread(entry.likeTime, lastViewAt: model.messageLikes.lastViewAt),
            destination: destination
        ) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: entry.primaryUser?.avatarURL, size: 42)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(likeSummary(entry))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text("赞了你的\(item?.businessLabel ?? "内容")")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(relativeTime(entry.likeTime))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    if !content.isEmpty {
                        Text(content)
                            .font(.system(size: 13))
                            .lineSpacing(2.5)
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func systemRow(_ message: SystemMessage) -> some View {
        let destination = message.webURL.map { MessageDestination.external($0) }
        return messageCard(unread: false, destination: destination) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                    if let cover = message.coverURL {
                        RemoteImage(url: cover, contentMode: .fit)
                            .padding(6)
                    }
                }
                .frame(width: 42, height: 42)
                .background(AppTheme.chip(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
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
                        Spacer(minLength: 8)
                        Text(systemTime(message.timeAt))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.tertiary(scheme))
                    }

                    let body = message.bodyText
                    if !body.isEmpty {
                        Text(body)
                            .font(.system(size: 13))
                            .lineSpacing(2.5)
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(5)
                            .textSelection(.enabled)
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
        let card = HStack(alignment: .top, spacing: 10) {
            content()
            Spacer(minLength: 4)
            VStack(spacing: 10) {
                if unread {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 7, height: 7)
                }
                if let destination {
                    Image(systemName: destination.isExternal ? "arrow.up.right" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.surface(scheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.divider(scheme), lineWidth: 1)
        )

        return Group {
            if let destination {
                Button {
                    model.openMessageDestination(destination)
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
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.secondary(scheme))
            .lineLimit(2)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.chip(scheme),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
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

private extension MessageDestination {
    var isExternal: Bool {
        if case .external = self { return true }
        return false
    }
}
