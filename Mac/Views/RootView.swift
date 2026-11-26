import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isSidebarVisible = true
    @State private var transition = PlayerTransitionController()
    @State private var rootSize: CGSize = .zero
    @AppStorage("app.appearance") private var appearance = "system"

    var body: some View {
        @Bindable var model = model

        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                AppTheme.background(scheme)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    if isSidebarVisible, !model.isTheaterActive, model.coreState == .ready {
                        SidebarView()
                            .frame(width: 240)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .zIndex(1)
                    }

                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if model.coreState == .ready,
                   let video = model.currentVideo,
                   transition.isDetailVisible {
                    VideoDetailView(video: video)
                        .id(video.bvid)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.background(scheme))
                        .opacity(transition.detailOpacity)
                        .allowsHitTesting(transition.isSettled)
                        .accessibilityHidden(!transition.isSettled)
                        .zIndex(1)
                }

                TransitionSkeletonView(playerFrame: playerFrame(in: geo.size))
                    .zIndex(2)

                HeroOverlayView()
                    .zIndex(10)
            }
            .coordinateSpace(.named("appRoot"))
            .environment(transition)
            .onAppear {
                rootSize = geo.size
            }
            .onChange(of: geo.size) { _, size in
                rootSize = size
            }
        }
        .navigationTitle("BTB")
        .toolbar(model.isTheaterActive ? .hidden : .visible, for: .windowToolbar)
        .toolbar {
            navigationToolbarItem

            ToolbarItem(placement: .principal) {
                ToolbarSearchField(
                    text: Binding(
                        get: { model.searchTerm },
                        set: { model.searchTerm = $0 }
                    ),
                    focusToken: model.focusSearchToken
                ) {
                    Task { await model.submitSearch() }
                }
                .frame(width: 360)
                .disabled(model.coreState != .ready)
            }

            accountToolbarItem
        }
        .sheet(isPresented: $model.isLoginSheetPresented) {
            LoginView()
                .environment(model)
        }
        .frame(minWidth: 1000, minHeight: 660)
        .preferredColorScheme(appearanceScheme)
        .onChange(of: model.navigationPath.isEmpty) { _, isEmpty in
            if isEmpty {
                transition.reset()
            } else {
                beginOpenTransition()
            }
        }
        .onChange(of: model.searchTerm) { _, _ in
            model.scheduleSearchSuggestions()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard let window = NSApp.keyWindow,
                      window.firstResponder is NSSearchField else { return }
                window.makeFirstResponder(nil)
            }
#if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BTB_WINDOW_SIZE"] {
                let parts = raw.split(separator: "x").compactMap { Double($0) }
                if parts.count == 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })
                            ?? NSApp.windows.first else { return }
                        window.setContentSize(NSSize(width: parts[0], height: parts[1]))
                    }
                }
            }
#endif
        }
        .onDisappear {
            model.shutdown()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.coreState {
        case .starting where model.videos.isEmpty:
            StartupView()
        case .failed(let message):
            CoreFailureView(message: message) {
                Task { await model.restartCore() }
            }
        case .ready, .starting:
            backgroundContent
                .id(backgroundID)
                .opacity(model.currentVideo == nil || !transition.isSettled ? 1 : 0)
                .allowsHitTesting(model.currentVideo == nil)
                .accessibilityHidden(model.currentVideo != nil)
        }
    }

    private var appearanceScheme: ColorScheme? {
#if DEBUG
        switch ProcessInfo.processInfo.environment["BTB_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: break
        }
#endif
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func beginOpenTransition() {
        guard let video = model.currentVideo,
              let cover = video.coverURL,
              ImageCache.shared.image(for: cover) != nil,
              let source = transition.sourceFrame(for: video.bvid) else {
            transition.completeOpenImmediately()
            return
        }
        transition.beginOpen(
            video: video,
            from: source,
            to: playerFrame(in: rootSize)
        )
    }

    private func playerFrame(in size: CGSize) -> CGRect {
        let available = max(1, min(size.width, 1600) - 48)
        let isWide = size.width >= 1120
        let width = isWide ? max(1, available - 24 - 342) : available
        return CGRect(x: 24, y: 16, width: width, height: width * 9 / 16)
    }

    @ViewBuilder
    private var backgroundContent: some View {
        if let room = model.activeLiveRoom {
            LiveRoomView(room: room)
        } else if model.activeAnimeSeasonID != nil {
            AnimeSeasonView()
        } else if model.activeArticleID != nil {
            ArticleView()
        } else if let topic = model.activeTopic {
            TopicView(topic: topic)
        } else if let dynamic = model.activeDynamic {
            DynamicDetailView(card: dynamic)
        } else if let download = model.activeDownload {
            DownloadDetailView(job: download)
        } else if let mid = model.activeUPMid {
            UserSpaceView(mid: mid)
        } else {
            switch model.section {
            case .home:
                HomeView()
            case .dynamic:
                DynamicFeedView()
            case .live:
                LiveFeedView()
            case .anime:
                AnimeFeedView()
            case .discover:
                DiscoverView()
            case .messages:
                MessagesView()
            case .search:
                SearchView()
            case .profile:
                ProfileView()
            case .uploads:
                MyUploadsView()
            case .history:
                HistoryView()
            case .playlists:
                PlaylistsView()
            case .watchLater:
                WatchLaterView()
            case .downloads:
                DownloadView()
            case .settings:
                SettingsView()
            }
        }
    }

    private var backgroundID: String {
        if let room = model.activeLiveRoom { return "live-\(room.roomID)" }
        if let seasonID = model.activeAnimeSeasonID { return "anime-\(seasonID)" }
        if let articleID = model.activeArticleID { return "article-\(articleID)" }
        if let topic = model.activeTopic { return "topic-\(topic.id)" }
        if let dynamic = model.activeDynamic { return "dynamic-\(dynamic.id)" }
        if let download = model.activeDownload { return "download-\(download.id)" }
        if let mid = model.activeUPMid { return "up-\(mid)" }
        return model.section.rawValue
    }

    @ToolbarContentBuilder
    private var navigationToolbarItem: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                navigationControls
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) {
                navigationControls
            }
        }
    }

    @ToolbarContentBuilder
    private var accountToolbarItem: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .primaryAction) {
                accountButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) {
                accountButton
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 3) {
            if model.currentVideo != nil || model.activeUPMid != nil || model.activeDynamic != nil || model.activeLiveRoom != nil || model.activeAnimeSeasonID != nil || model.activeArticleID != nil || model.activeTopic != nil || model.activeDownload != nil {
                ToolbarGlyphButton(systemName: "chevron.backward", help: "返回") {
                    if model.currentVideo != nil {
                        model.closeVideo()
                    } else if model.activeLiveRoom != nil {
                        model.closeLiveRoom()
                    } else if model.activeAnimeSeasonID != nil {
                        model.closeAnimeSeason()
                    } else if model.activeArticleID != nil {
                        model.closeArticle()
                    } else if model.activeTopic != nil {
                        model.closeTopic()
                    } else if model.activeDynamic != nil {
                        model.closeDynamic()
                    } else if model.activeDownload != nil {
                        model.closeDownload()
                    } else {
                        model.closeUP()
                    }
                }
            }

            ToolbarGlyphButton(
                systemName: "sidebar.left",
                help: isSidebarVisible ? "收起导航" : "展开导航",
                isDisabled: model.coreState != .ready
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarVisible.toggle()
                }
            }

            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 6)

            AppMark(size: 17)
                .accessibilityHidden(true)
        }
    }

    private var accountButton: some View {
        Button {
            model.presentLogin()
        } label: {
            Group {
                if let url = model.profile?.avatarURL ?? model.activeAccount?.avatarURL {
                    AvatarView(url: url, size: 24)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 24, height: 24)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("账号")
    }
}

private struct ToolbarGlyphButton: View {
    let systemName: String
    var help: String = ""
    var isDisabled = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(
                    isDisabled
                        ? AppTheme.tertiary(scheme).opacity(0.45)
                        : (isHovering ? AppTheme.text(scheme) : AppTheme.secondary(scheme))
                )
                .frame(width: 28, height: 28)
                .background(
                    AppTheme.hover(scheme).opacity(isHovering && !isDisabled ? 1 : 0),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(help)
    }
}

private struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    var focusToken: Int
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "搜索哔哩哔哩"
        field.controlSize = .large
        field.font = .systemFont(ofSize: 13)
        field.sendsSearchStringImmediately = false
        field.sendsWholeSearchString = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.setAccessibilityLabel("搜索哔哩哔哩")
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }

        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        DispatchQueue.main.async {
            guard let window = field.window else { return }
            window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ToolbarSearchField
        var lastFocusToken: Int

        init(_ parent: ToolbarSearchField) {
            self.parent = parent
            self.lastFocusToken = parent.focusToken
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        @objc func submit(_ sender: NSSearchField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }
    }
}

private struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let mySections: [SidebarSection] = [
        .profile, .uploads, .history, .playlists, .watchLater, .downloads, .settings,
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarRow(.home)
                    sidebarRow(.dynamic)
                    sidebarRow(.live)
                    sidebarRow(.anime)
                    sidebarRow(.discover)
                    sidebarRow(.messages)
                    recentSection
                    mySection
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            accountCard
                .padding(12)
        }
        .background(AppTheme.background(scheme))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if model.isLoadingRecentUPs || !model.recentUPs.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                sectionHeader("最近更新")

                if model.recentUPs.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在加载…")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                } else {
                    ForEach(Array(model.recentUPs.prefix(5))) { up in
                        upRow(up)
                    }
                }
            }
        }
    }

    private var mySection: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionHeader("我")
            ForEach(mySections) { section in
                sidebarRow(section)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.secondary(scheme))
            .padding(.horizontal, 11)
            .padding(.top, 2)
            .padding(.bottom, 5)
    }

    private func sidebarRow(_ section: SidebarSection) -> some View {
        let isSelected = model.currentVideo == nil
            && model.activeUPMid == nil
            && model.activeDynamic == nil
            && model.activeLiveRoom == nil
            && model.activeAnimeSeasonID == nil
            && model.activeArticleID == nil
            && model.activeTopic == nil
            && model.activeDownload == nil
            && model.section == section
        return Button {
            model.selectSection(section)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .frame(width: 22)
                Text(section.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 0)
                if section == .messages,
                   let unread = model.messageUnread?.total,
                   unread > 0 {
                    Text(unread > 99 ? "99+" : "\(unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(AppTheme.brand, in: Capsule())
                }
            }
            .foregroundStyle(AppTheme.text(scheme))
            .padding(.horizontal, 11)
            .frame(height: 40)
            .background(
                isSelected ? AppTheme.chip(scheme) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func upRow(_ up: RecentUP) -> some View {
        let isSelected = model.activeUPMid == up.mid
        return Button {
            model.openUP(up)
        } label: {
            HStack(spacing: 10) {
                AvatarView(url: up.avatarURL, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(up.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)
                    Text(up.latestTitle.isEmpty ? up.updateText : up.latestTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 46)
            .background(
                isSelected ? AppTheme.chip(scheme) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开 \(up.name) 的主页")
    }

    private var accountCard: some View {
        Button {
            model.presentLogin()
        } label: {
            GlassSurface(shape: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))) {
                HStack(spacing: 10) {
                    if let url = model.profile?.avatarURL ?? model.activeAccount?.avatarURL {
                        AvatarView(url: url, size: 34)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .frame(width: 34, height: 34)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.profile?.name ?? model.activeAccount?.displayName ?? "登录 BTB")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .lineLimit(1)
                        Text(model.activeAccount == nil ? "同步收藏、关注与历史" : "管理账号")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .help("账号")
    }
}

private struct StartupView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 16) {
            AppMark(size: 58)
            ProgressView()
                .controlSize(.small)
            Text("正在加载…")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondary(scheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background(scheme))
    }
}
