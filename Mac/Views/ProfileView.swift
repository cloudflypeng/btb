import AppKit
import SwiftUI

private enum ProfileTab {
    case uploads
    case history
    case following
    case followers
}

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab: ProfileTab = .uploads

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 380), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.isProfileLoading && model.profile == nil {
                    ProgressView("正在加载个人主页…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 110)
                } else if let profile = model.profile {
                    header(profile)
                    if let error = model.profileError {
                        ErrorBanner(text: error) {
                            Task { await model.refreshProfile() }
                        }
                    }
                    tabs
                    tabContent
                } else {
                    loggedOut
                }
            }
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        #if DEBUG
        .task {
            switch ProcessInfo.processInfo.environment["BTB_PROFILE_TAB"] {
            case "history": selectedTab = .history
            case "following": selectedTab = .following
            case "followers": selectedTab = .followers
            default: break
            }
            let env = ProcessInfo.processInfo.environment
            if let raw = env["BTB_FOLLOW_TAG"], let tagID = Int64(raw) {
                await model.loadFollowTags()
                await model.selectFollowTag(tagID)
            }
            if let keyword = env["BTB_FOLLOW_SEARCH"], !keyword.isEmpty {
                model.followSearchInput = keyword
                await model.searchFollowing()
            }
        }
        #endif
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .frame(height: 105)

            HStack(alignment: .top, spacing: 18) {
                AvatarView(url: profile.avatarURL, size: 92)
                    .offset(y: -52)
                    .padding(.bottom, -52)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.text(scheme))
                        Text("LV\(profile.level)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.brand, in: Capsule())
                        if model.isProfileLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text("UID \(profile.mid)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .textSelection(.enabled)

                    if !profile.sign.isEmpty {
                        Text(profile.sign)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 20) {
                        Button {
                            withAnimation(BtbMotion.snappy) {
                                selectedTab = .following
                            }
                        } label: {
                            statistic("关注", value: profile.following)
                        }
                        .buttonStyle(.plain)
                        .help("查看我的关注")

                        Button {
                            withAnimation(BtbMotion.snappy) {
                                selectedTab = .followers
                            }
                        } label: {
                            statistic("粉丝", value: profile.follower)
                        }
                        .buttonStyle(.plain)
                        .help("查看我的粉丝")
                    }
                    .padding(.top, 5)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button {
                        Task { await model.refreshProfile() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(AppTheme.chip(scheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isProfileLoading)
                    .help("刷新个人主页")

                    Button {
                        model.presentLogin()
                    } label: {
                        Label("管理账号", systemImage: "person.crop.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 8)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            TagChip(title: "最近投稿", isSelected: selectedTab == .uploads) {
                withAnimation(BtbMotion.snappy) {
                    selectedTab = .uploads
                }
            }
            TagChip(title: "最近观看", isSelected: selectedTab == .history) {
                withAnimation(BtbMotion.snappy) {
                    selectedTab = .history
                }
            }
            TagChip(title: "我的关注", isSelected: selectedTab == .following) {
                withAnimation(BtbMotion.snappy) {
                    selectedTab = .following
                }
            }
            TagChip(title: "我的粉丝", isSelected: selectedTab == .followers) {
                withAnimation(BtbMotion.snappy) {
                    selectedTab = .followers
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .uploads:
            if model.uploads.isEmpty {
                emptySection(title: "还没有投稿", message: "这里会显示最近发布的视频。")
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                    ForEach(model.uploads) { video in
                        Button {
                            model.openVideo(video)
                        } label: {
                            VideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .history:
            if model.history.isEmpty {
                emptySection(title: "还没有观看记录", message: "看过的视频会出现在这里。")
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(model.history) { video in
                        Button {
                            model.openVideo(video)
                        } label: {
                            HistoryRow(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .following:
            followingTab
        case .followers:
            followersTab
        }
    }

    private var followingTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            followingToolbar

            if let error = model.followingError {
                ErrorBanner(text: error) {
                    Task { await model.loadFollowing(force: true) }
                }
            }

            if !model.hasAccount {
                emptySection(title: "登录后查看关注", message: "登录后可以看到你关注的 UP 主。")
            } else if model.isLoadingFollowing && model.followingUPs.isEmpty {
                FollowingSkeletonList()
            } else if model.followingUPs.isEmpty {
                followingEmptySection
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(model.followingUPs) { up in
                        Button {
                            model.openUP(mid: up.mid, name: up.name, avatarURL: up.avatarURL)
                        } label: {
                            FollowingRow(up: up)
                        }
                        .buttonStyle(.plain)
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingFollowing || model.followingPager.isLoadingMore,
                        hasMore: model.followingPager.hasMore,
                        failed: model.followingPager.failed
                    ) {
                        Task { await model.loadMoreFollowing() }
                    }
                }
            }
        }
        .task {
            await model.loadFollowTags()
            await model.loadFollowing()
        }
    }

    private var followingToolbar: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let error = model.followTagsError {
                ErrorBanner(text: error) {
                    Task { await model.loadFollowTags(force: true) }
                }
            }

            HStack(spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        FollowGroupChip(
                            title: "全部",
                            count: model.profile?.following,
                            isSpecial: false,
                            isSelected: model.followSearchKeyword.isEmpty && model.selectedFollowTagID == nil
                        ) {
                            Task { await model.selectFollowTag(nil) }
                        }

                        ForEach(model.followTags) { tag in
                            FollowGroupChip(
                                title: tag.name,
                                count: tag.count,
                                isSpecial: tag.isSpecial,
                                isSelected: model.followSearchKeyword.isEmpty && model.selectedFollowTagID == tag.tagid
                            ) {
                                Task { await model.selectFollowTag(tag.tagid) }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)

                FollowingSearchField(
                    text: Binding(
                        get: { model.followSearchInput },
                        set: { model.followSearchInput = $0 }
                    ),
                    isActive: !model.followSearchKeyword.isEmpty,
                    onSubmit: { Task { await model.searchFollowing() } },
                    onClear: { Task { await model.clearFollowingSearch() } }
                )
            }
        }
    }

    @ViewBuilder
    private var followingEmptySection: some View {
        if !model.followSearchKeyword.isEmpty {
            emptySection(title: "没有找到匹配的 UP 主", message: "换个关键词试试。")
        } else if let tag = model.followTags.first(where: { $0.tagid == model.selectedFollowTagID }) {
            emptySection(title: "这个分组还没有成员", message: "“\(tag.name)”分组下暂无 UP 主。")
        } else {
            emptySection(title: "还没有关注任何人", message: "关注的 UP 主会出现在这里。")
        }
    }

    private var followersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.followersError {
                ErrorBanner(text: error) {
                    Task { await model.loadFollowers(force: true) }
                }
            }

            if !model.hasAccount {
                emptySection(title: "登录后查看粉丝", message: "登录后可以看到关注你的用户。")
            } else if model.isLoadingFollowers && model.followers.isEmpty {
                FollowingSkeletonList()
            } else if model.followers.isEmpty {
                emptySection(title: "还没有粉丝", message: "关注你的用户会出现在这里。")
            } else {
                HStack(spacing: 8) {
                    Text("共 \(formatCount(model.followersTotal)) 位粉丝")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    Spacer()
                }
                .padding(.horizontal, 4)

                LazyVStack(spacing: 6) {
                    ForEach(model.followers) { up in
                        Button {
                            model.openUP(mid: up.mid, name: up.name, avatarURL: up.avatarURL)
                        } label: {
                            FollowingRow(up: up)
                        }
                        .buttonStyle(.plain)
                    }

                    InfiniteScrollFooter(
                        isLoading: model.isLoadingFollowers || model.followersPager.isLoadingMore,
                        hasMore: model.followersPager.hasMore,
                        failed: model.followersPager.failed,
                        endText: "没有更多粉丝了"
                    ) {
                        Task { await model.loadMoreFollowers() }
                    }
                }
            }
        }
        .task {
            await model.loadFollowers()
        }
    }

    private func emptySection(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var loggedOut: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(AppTheme.brand)

            Text("登录后查看个人主页")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))

            Text("同步你的投稿、收藏、关注与观看记录。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))

            if let error = model.profileError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button {
                model.presentLogin()
            } label: {
                Label("扫码登录", systemImage: "qrcode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 92)
    }

    private func statistic(_ title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(formatCount(value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondary(scheme))
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
}

private struct FollowGroupChip: View {
    let title: String
    let count: Int?
    let isSpecial: Bool
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSpecial {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                if let count, count > 0 {
                    Text(SearchFormat.count(count))
                        .font(.system(size: 10.5))
                        .opacity(0.62)
                }
            }
            .foregroundStyle(isSelected ? AppTheme.selectedText(scheme) : AppTheme.text(scheme))
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                isSelected
                    ? AppTheme.selected(scheme)
                    : (isHovering ? AppTheme.surfaceHover(scheme) : AppTheme.chip(scheme)),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct FollowingSearchField: View {
    @Binding var text: String
    let isActive: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? AppTheme.brand : AppTheme.tertiary(scheme))

            TextField("在关注中搜索", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.text(scheme))
                .onSubmit(onSubmit)

            if !text.isEmpty || isActive {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 210, height: 30)
        .background(AppTheme.chip(scheme), in: Capsule())
    }
}

private struct FollowingRow: View {
    let up: FollowingUP

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: up.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(up.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)

                    if !up.officialDesc.isEmpty {
                        Text(up.officialDesc)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }

                    if up.isSpecial {
                        badge("特别关注", icon: "star.fill", tint: AppTheme.brand)
                    } else if up.isMutual {
                        badge("互关", icon: "person.2.fill", tint: AppTheme.accent)
                    }
                }

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary(scheme))
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(
            isHovering ? AppTheme.hover(scheme) : AppTheme.surface(scheme),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func badge(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .frame(height: 17)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var subtitle: String {
        if !up.sign.isEmpty { return up.sign }
        return "UP 主 · UID \(up.mid)"
    }
}

private struct FollowingSkeletonList: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surface(scheme))
                    .frame(height: 64)
            }
        }
        .allowsHitTesting(false)
    }
}
