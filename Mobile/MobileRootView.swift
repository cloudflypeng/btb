import SwiftUI

enum MobileTab: Hashable {
    case home
    case dynamic
    case discover
    case messages
    case profile
}

struct MobileUPRoute: Hashable {
    let mid: Int64
    let name: String
    let avatarURL: URL?
}

struct MobileRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var router = MobileRouter()
    @Namespace private var playerTransition
#if DEBUG
    @State private var didOpenDebugVideo = false
#endif

    /// A tab that is already selected reports a re-tap instead of a switch.
    private var tabSelection: Binding<MobileTab> {
        Binding(
            get: { router.selectedTab },
            set: { tab in
                if tab == router.selectedTab {
                    router.retapToken += 1
                }
                router.selectedTab = tab
            }
        )
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var router = router

        // The system tab bar is hidden for good: `MobileTabBar` draws the same
        // bar as an ordinary view so it can slide off with the header.
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                NavigationStack {
                    MobileHomeView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(MobileTab.home)

                NavigationStack {
                    MobileDynamicView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(MobileTab.dynamic)

                NavigationStack {
                    MobileDiscoverView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(MobileTab.discover)

                NavigationStack {
                    MobileMessageView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(MobileTab.messages)

                NavigationStack {
                    MobileProfileView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(MobileTab.profile)
            }
            // Room for the bar, reserved whether or not it is showing, so the
            // feed never re-lays out when it leaves.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 58)
            }

            MobileTabBar(
                selection: router.selectedTab,
                badge: model.messageUnread?.total ?? 0,
                hidden: router.tabBarHidden
            ) { tab in
                if tab == router.selectedTab {
                    router.retapToken += 1
                } else {
                    router.selectedTab = tab
                }
            }
            .padding(.bottom, 4)
        }
        .tint(AppTheme.text(scheme))
        .background(AppTheme.background(scheme))
        .environment(router)
        .environment(\.playerTransitionNamespace, playerTransition)
        .overlay(alignment: .bottom) {
            if let toast = model.toastMessage {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(.black.opacity(0.82), in: Capsule())
                    .padding(.bottom, 76)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(BtbMotion.snappy, value: model.toastMessage)
        .overlay {
            launchOverlay
        }
        // #8: the player is a full-screen cover, not a sheet — no drag handle,
        // no swipe-to-dismiss, and leaving it is an explicit back button that
        // also stops the video.
        .fullScreenCover(isPresented: $router.isPlayerPresented) {
            NavigationStack(path: $router.path) {
                if let video = router.rootVideo {
                    MobilePlayerView(video: video)
                        .id(video.bvid)
                        .navigationDestination(for: MobileSheetRoute.self) { route in
                            switch route {
                            case .up(let up):
                                MobileUPView(route: up)
                            }
                        }
                }
            }
            .environment(model)
            .environment(router)
            .modifier(PlayerZoomTransition(bvid: router.rootVideo?.bvid, namespace: playerTransition))
            .presentationBackground(AppTheme.background(scheme))
            .sheet(isPresented: $model.isLoginSheetPresented) {
                MobileLoginView()
                    .environment(model)
            }
        }
        .sheet(isPresented: Binding(
            get: { model.isLoginSheetPresented && !router.isPlayerPresented },
            set: { model.isLoginSheetPresented = $0 }
        )) {
            MobileLoginView()
                .environment(model)
        }
        .task(id: model.activeAccount?.mid) {
            guard model.hasAccount else { return }
            await model.loadMessageUnread(force: true)
        }
        .onAppear {
            // B6: the PiP expand button brings the player page back.
            MobilePiPSession.onRestore = { video in
                router.open(video)
            }
        }
        .onChange(of: model.coreState) { _, state in
            guard state == .ready else { return }
            if model.hasAccount {
                Task { await model.loadMessageUnread(force: true) }
            }
#if DEBUG
            openDebugVideoIfNeeded()
#endif
        }
#if DEBUG
        .onAppear {
            switch debugOption("BTB_MOBILE_TAB") {
            case "home": router.selectedTab = .home
            case "dynamic": router.selectedTab = .dynamic
            case "discover": router.selectedTab = .discover
            case "messages": router.selectedTab = .messages
            case "profile": router.selectedTab = .profile
            default: break
            }
            openDebugVideoIfNeeded()
        }
#endif
    }

#if DEBUG
    private func debugOption(_ key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-\(key)"), index + 1 < arguments.count {
            return arguments[index + 1]
        }
        return ProcessInfo.processInfo.environment[key]
    }

    private func openDebugVideoIfNeeded() {
        guard !didOpenDebugVideo, model.coreState == .ready else { return }
        // Replays press → open on the real router, so tap-to-first-frame can be
        // measured on a device via `devicectl device process launch --console`.
        if debugOption("BTB_AUTO_OPEN") == "1", let first = model.videos.first {
            didOpenDebugVideo = true
            let pressMS = UInt64(Int(debugOption("BTB_AUTO_OPEN_DELAY") ?? "") ?? 500)
            model.prefetchPlayback(first)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: pressMS * 1_000_000)
                Perf.milestone("autoOpen.tap", "press=\(pressMS) ms")
                router.open(first)
                // B6: leave the page while it plays, to exercise the PiP hand-off
                // on a device that cannot be tapped from the automation host.
                guard let closeMS = Int(debugOption("BTB_AUTO_CLOSE") ?? ""), closeMS > 0 else { return }
                try? await Task.sleep(nanoseconds: UInt64(closeMS) * 1_000_000)
                Perf.milestone("autoClose.dismiss", "after=\(closeMS) ms")
                router.dismiss()
            }
            return
        }
        guard let bvid = debugOption("BTB_MOBILE_OPEN_BVID"),
              !bvid.isEmpty else {
            return
        }
        didOpenDebugVideo = true
        router.open(VideoItem(bvid: bvid))
    }
#endif

    @ViewBuilder
    private var launchOverlay: some View {
        switch model.coreState {
        case .ready:
            EmptyView()
        case .starting where !model.videos.isEmpty:
            // Cached feed is already on screen; don't hide it behind a splash.
            EmptyView()
        case .starting:
            ZStack {
                AppTheme.background(scheme).ignoresSafeArea()
                VStack(spacing: 16) {
                    AppMark(size: 64)
                    Text("BTB")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    ProgressView()
                        .tint(AppTheme.brand)
                        .padding(.top, 4)
                    Text("正在连接核心服务…")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }
        case .failed(let message):
            ZStack {
                AppTheme.background(scheme).ignoresSafeArea()
                VStack(spacing: 16) {
                    AppMark(size: 64)
                    Text("无法连接核心服务")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                    Button {
                        Task { await model.restartCore() }
                    } label: {
                        Text("重新连接")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 42)
                            .background(AppTheme.brand, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
    }
}
