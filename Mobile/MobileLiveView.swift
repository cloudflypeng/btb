import AVKit
import Combine
import SwiftUI

struct MobileLiveListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedRoom: LiveRoom?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            Divider().opacity(0.5)
            content
        }
        .background(AppTheme.background(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $selectedRoom) { room in
            MobileLiveRoomView(room: room)
        }
        .task {
            if model.hasAccount && (!model.liveLoaded || model.liveRooms.isEmpty) {
                await model.loadLiveFeed(reset: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("直播")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
            if model.liveFollowedLiveCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: 0xFF3B5C))
                        .frame(width: 6, height: 6)
                    Text("\(model.liveFollowedLiveCount) 个关注正在直播")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }
            Spacer()
            Button {
                Task { await model.loadLiveFeed(reset: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.chip(scheme), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isLoadingLive || !model.hasAccount)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(LiveFeedFilter.allCases) { filter in
                MobilePill(title: filter.title, isSelected: model.liveFeedFilter == filter) {
                    model.setLiveFeedFilter(filter)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if !model.hasAccount {
                loginState
            } else if model.isLoadingLive && model.liveRooms.isEmpty {
                ProgressView()
                    .tint(AppTheme.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if let error = model.liveError, model.liveRooms.isEmpty {
                MobileErrorBanner(text: error) {
                    Task { await model.loadLiveFeed(reset: true) }
                }
                .padding(14)
            } else if model.filteredLiveRooms.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(model.filteredLiveRooms) { room in
                        MobileLiveRoomCard(room: room) {
                            selectedRoom = room
                        }
                    }
                }
                .padding(14)

                InfiniteScrollFooter(
                    isLoading: model.isLoadingLive,
                    hasMore: model.liveHasMore,
                    failed: model.liveError != nil,
                    endText: "没有更多直播间了"
                ) {
                    Task { await model.loadMoreLive() }
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await model.loadLiveFeed(reset: true)
        }
    }

    private var loginState: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text("登录后查看关注的直播")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Button {
                model.presentLogin()
            } label: {
                Text("登录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.selectedText(scheme))
                    .padding(.horizontal, 24)
                    .frame(height: 36)
                    .background(AppTheme.selected(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: model.liveFeedFilter == .live ? "moon.zzz" : "dot.radiowaves.left.and.right")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text(model.liveFeedFilter == .live ? "关注的主播都还没开播" : "还没有关注的直播间")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            if model.liveFeedFilter == .live, !model.liveRooms.isEmpty {
                Button("查看全部关注") {
                    model.setLiveFeedFilter(.all)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.brand)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

struct MobileLiveRoomCard: View {
    let room: LiveRoom
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 7) {
                RemoteImage(url: room.coverURL)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .overlay(alignment: .topLeading) {
                        Text(room.isLive ? "直播中" : "未开播")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 19)
                            .background(room.isLive ? Color(hex: 0xFF3B5C) : Color.black.opacity(0.55), in: Capsule())
                            .padding(7)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if room.isLive, !room.popularText.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8.5, weight: .semibold))
                                Text(room.popularText)
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.bottom, 5)
                        }
                    }

                Text(room.title.isEmpty ? "直播间" : room.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 34, alignment: .top)

                HStack(spacing: 5) {
                    AvatarView(url: room.avatarURL, size: 16)
                    Text(room.anchorName.isEmpty ? "未知主播" : room.anchorName)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct MobileLiveRoomView: View {
    let room: LiveRoom

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isPresentingFullscreen = false

    var body: some View {
        VStack(spacing: 0) {
            MobileLivePlayer(room: room, isPresentingFullscreen: $isPresentingFullscreen)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            infoBar

            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(height: 1)

            MobileLiveChatList()
        }
        .background(AppTheme.background(scheme))
        .safeAreaInset(edge: .bottom) {
            MobileLiveComposer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            guard model.activeLiveRoom?.roomID != room.roomID else { return }
            model.openLiveRoom(room)
        }
        .onDisappear {
            if !isPresentingFullscreen {
                model.closeLiveRoom()
            }
        }
    }

    private var info: LiveRoomInfo? {
        model.activeLiveRoom?.roomID == room.roomID ? model.liveRoomInfo : nil
    }

    private var anchorName: String {
        let name = info?.anchorName ?? room.anchorName
        return name.isEmpty ? "未知主播" : name
    }

    private var title: String {
        let value = info?.title ?? room.title
        return value.isEmpty ? "直播间" : value
    }

    private var areaText: String {
        let value = info?.areaName ?? room.areaName
        guard !value.isEmpty else { return "" }
        if let parent = info?.parentAreaName, !parent.isEmpty, parent != value {
            return "\(parent) · \(value)"
        }
        return value
    }

    private var online: Int {
        model.livePopularity > 0 ? model.livePopularity : (info?.online ?? 0)
    }

    private var watched: Int {
        model.liveWatched > 0 ? model.liveWatched : (info?.watched ?? 0)
    }

    private var infoBar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if !areaText.isEmpty {
                            Text(areaText)
                        }
                        if online > 0 {
                            Text("\(MobileFormat.count(online)) 人气")
                        }
                        if watched > 0 {
                            Text("\(MobileFormat.count(watched)) 看过")
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                }
                Spacer(minLength: 0)

                ShareLink(item: info?.pageURL ?? room.pageURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 30, height: 30)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 9) {
                AvatarView(url: info?.avatarURL ?? room.avatarURL, size: 30)
                Text(anchorName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    Task { await model.toggleLiveFollow() }
                } label: {
                    Text(model.liveIsFollowing ? "已关注" : "关注")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(model.liveIsFollowing ? AppTheme.text(scheme) : .white)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(model.liveIsFollowing ? AppTheme.chip(scheme) : AppTheme.brand, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct MobileLivePlayer: View {
    let room: LiveRoom
    @Binding var isPresentingFullscreen: Bool

    @Environment(AppModel.self) private var model
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var isReady = false
    @State private var loadFailed = false
    @State private var statusCancellable: AnyCancellable?
    @State private var fullscreenHost: LandscapePlayerHost?

    private var playbackURL: URL? {
        guard model.livePlayback?.playable == true else { return nil }
        return model.livePlayback?.playbackURL
    }

    var body: some View {
        ZStack {
            Color.black

            if playbackURL != nil {
                LiveSurface(player: player)
                    .opacity(isReady ? 1 : 0)
                if !isReady && !loadFailed {
                    RemoteImage(url: model.liveRoomInfo?.coverURL ?? room.coverURL)
                        .opacity(0.4)
                    ProgressView()
                        .tint(.white)
                }
                MobileLiveControls(
                    player: player,
                    isPlaying: $isPlaying,
                    isFullscreen: false,
                    onFullscreen: enterFullscreen
                )
                if loadFailed {
                    failureOverlay
                }
            } else if model.isLoadingLivePlay {
                ProgressView()
                    .tint(.white)
            } else {
                unavailableState
            }
        }
        .clipped()
        .onAppear {
            applyPlayback()
        }
        .onChange(of: playbackURL) { _, _ in
            applyPlayback()
        }
        .onDisappear {
            if fullscreenHost == nil {
                player.pause()
            }
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 9) {
            Image(systemName: "tv.slash")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text(model.livePlayError ?? model.livePlayback?.unavailableText ?? "直播暂不可播放")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            Button {
                Task { await model.refreshLivePlayback() }
            } label: {
                Text("重试")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var failureOverlay: some View {
        VStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.orange)
            Text("直播流播放失败")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Button {
                Task { await model.refreshLivePlayback() }
            } label: {
                Text("重试")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applyPlayback() {
        statusCancellable = nil
        loadFailed = false
        guard let url = playbackURL else {
            isReady = false
            player.pause()
            isPlaying = false
            return
        }
        if (player.currentItem?.asset as? AVURLAsset)?.url != url {
            isReady = false
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            statusCancellable = item.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .sink { status in
                    switch status {
                    case .readyToPlay:
                        isReady = true
                    case .failed:
                        loadFailed = true
                        isPlaying = false
                    default:
                        break
                    }
                }
        }
        player.play()
        isPlaying = true
    }

    @MainActor
    private func enterFullscreen() {
        guard fullscreenHost == nil else { return }
        guard let top = UIApplication.shared.topViewController() else { return }
        let canvas = ZStack {
            Color.black.ignoresSafeArea()
            LiveSurface(player: player)
            MobileLiveControls(
                player: player,
                isPlaying: $isPlaying,
                isFullscreen: true,
                onFullscreen: exitFullscreen
            )
        }
        .environment(model)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)

        let host = LandscapePlayerHost(rootView: AnyView(canvas))
        host.modalPresentationStyle = .fullScreen
        host.modalTransitionStyle = .crossDissolve
        fullscreenHost = host
        isPresentingFullscreen = true
        top.present(host, animated: false) {
            requestVideoOrientation(.landscapeRight)
        }
    }

    @MainActor
    private func exitFullscreen() {
        guard let host = fullscreenHost else { return }
        fullscreenHost = nil
        isPresentingFullscreen = false
        host.dismiss(animated: false) {
            requestVideoOrientation(.portrait)
        }
    }
}

private struct LiveSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        view.player = player
        return view
    }

    func updateUIView(_ view: VideoSurfaceView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}

private struct MobileLiveControls: View {
    @Environment(AppModel.self) private var model

    let player: AVPlayer
    @Binding var isPlaying: Bool
    let isFullscreen: Bool
    let onFullscreen: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.white)
                        .frame(width: 4, height: 4)
                    Text("直播")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color(hex: 0xFF3B5C), in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")

                Spacer()

                if !model.liveQualities.isEmpty {
                    Menu {
                        ForEach(model.liveQualities) { quality in
                            Button {
                                Task { await model.selectLiveQuality(quality.qn) }
                            } label: {
                                if quality.qn == model.liveSelectedQN {
                                    Label(quality.desc, systemImage: "checkmark")
                                } else {
                                    Text(quality.desc)
                                }
                            }
                        }
                    } label: {
                        Text(model.liveQualities.first(where: { $0.qn == model.liveSelectedQN })?.desc ?? "清晰度")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(.black.opacity(0.35), in: Capsule())
                    }
                    .accessibilityLabel("清晰度")
                }

                Button(action: onFullscreen) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, isFullscreen ? 22 : 10)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 90)
            .allowsHitTesting(false)
        }
    }
}

private struct MobileLiveChatList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    if model.liveChatMessages.isEmpty {
                        VStack(spacing: 8) {
                            if model.liveConnected {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(AppTheme.tertiary(scheme))
                                Text("暂无弹幕，稍等片刻")
                            } else {
                                ProgressView().controlSize(.small)
                                Text("正在连接弹幕…")
                            }
                        }
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                    } else {
                        ForEach(model.liveChatMessages) { message in
                            MobileLiveChatRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.liveChatMessages.count) { _, _ in
                guard let last = model.liveChatMessages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
        .background(AppTheme.surface(scheme))
    }
}

private struct MobileLiveChatRow: View {
    let message: LiveChatMessage

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch message.kind {
        case .superChat:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.userName)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                    if let price = message.price {
                        Text("¥\(price)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
                Text(message.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xFF6A00).opacity(0.82), Color(hex: 0xFF2D55).opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )

        case .gift:
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0xFF6699))
                (
                    Text(message.userName + " ")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                    + Text(message.text)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: 0xFF6699))
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(hex: 0xFF6699).opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

        case .enter:
            (
                Text(message.userName + " ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                + Text(message.text)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            )
            .frame(maxWidth: .infinity, alignment: .leading)

        case .system:
            (
                Text(message.userName + " ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                + Text(message.text)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.accent)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

        case .danmaku:
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let medalName = message.medalName {
                    Text("\(medalName) \(message.medalLevel ?? 0)")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(height: 15)
                        .background(AppTheme.brand.opacity(0.10), in: Capsule())
                }
                (
                    Text(message.userName + "：")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                    + Text(message.text)
                        .font(.system(size: 12))
                        .foregroundStyle(danmakuColor)
                )
                .fixedSize(horizontal: false, vertical: true)
                if message.isLocal {
                    Text("发送中")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var danmakuColor: Color {
        if let color = message.color, color > 0 {
            return Color(hex: color)
        }
        return AppTheme.text(scheme)
    }
}

private struct MobileLiveComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            if model.hasAccount {
                TextField("发送弹幕…", text: $draft)
                    .focused($isFocused)
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(AppTheme.chip(scheme), in: Capsule())
                    .onSubmit(send)

                Button(action: send) {
                    if model.isSendingLiveMessage {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.brand, in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSendingLiveMessage)
                .accessibilityLabel("发送弹幕")
            } else {
                Button {
                    model.presentLogin()
                } label: {
                    Text("登录后参与互动")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AppTheme.chip(scheme), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task {
            let sent = await model.sendLiveMessage(text)
            if !sent, draft.isEmpty {
                draft = text
            }
        }
    }
}
