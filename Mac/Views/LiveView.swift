import AVKit
import AppKit
import Combine
import SwiftUI

struct LiveFeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private let columns = [
        GridItem(.adaptive(minimum: 248, maximum: 360), spacing: 16, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !model.hasAccount {
                    loginState
                } else if model.isLoadingLive && model.liveRooms.isEmpty {
                    skeletonGrid
                } else if let error = model.liveError, model.liveRooms.isEmpty {
                    ErrorBanner(text: error) {
                        Task { await model.loadLiveFeed(reset: true) }
                    }
                } else if model.filteredLiveRooms.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(model.filteredLiveRooms) { room in
                            LiveRoomCard(room: room)
                                .onTapGesture {
                                    model.openLiveRoom(room)
                                }
                        }
                    }

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
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background(scheme))
        .task {
            if !model.liveLoaded || model.liveRooms.isEmpty {
                await model.loadLiveFeed(reset: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("直播")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                if model.liveFollowedLiveCount > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: 0xFF3B5C))
                            .frame(width: 6, height: 6)
                        Text("\(model.liveFollowedLiveCount) 个关注正在直播")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondary(scheme))
                    }
                }

                Spacer()

                Button {
                    Task { await model.loadLiveFeed(reset: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .frame(width: 30, height: 30)
                        .background(AppTheme.chip(scheme), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(model.isLoadingLive || !model.hasAccount)
                .help("刷新直播")
            }

            HStack(spacing: 8) {
                ForEach(LiveFeedFilter.allCases) { filter in
                    BtbPill(title: filter.title, isSelected: model.liveFeedFilter == filter) {
                        model.setLiveFeedFilter(filter)
                    }
                }
            }
        }
    }

    private var loginState: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 38, weight: .light))
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
                    .padding(.horizontal, 22)
                    .frame(height: 34)
                    .background(AppTheme.selected(scheme), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: model.liveFeedFilter == .live
                ? "moon.zzz"
                : "dot.radiowaves.left.and.right")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.tertiary(scheme))
            Text(model.liveFeedFilter == .live ? "关注的主播都还没开播" : "还没有关注的直播间")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
            Text(model.liveFeedFilter == .live
                ? "切换查看全部关注，或稍后再来。"
                : "在 B 站关注主播后，这里会显示他们的直播间。")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondary(scheme))
            if model.liveFeedFilter == .live, !model.liveRooms.isEmpty {
                Button("查看全部关注") {
                    model.setLiveFeedFilter(.all)
                }
                .buttonStyle(.link)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<6, id: \.self) { _ in
                LiveCardSkeleton()
            }
        }
    }
}

struct LiveRoomCard: View {
    let room: LiveRoom

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                LiveCoverImage(url: room.coverURL)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .bottomLeading) {
                        if room.isLive, !room.popularText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(room.popularText)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 7)
                            .padding(.bottom, 6)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        statusBadge
                            .padding(7)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 7) {
                AvatarView(url: room.avatarURL, size: 22)
                Text(room.anchorName.isEmpty ? "未知主播" : room.anchorName)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !room.areaName.isEmpty {
                    Text(room.areaName)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(AppTheme.chip(scheme), in: Capsule())
                        .lineLimit(1)
                }
            }

            Text(room.title.isEmpty ? "无标题直播" : room.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            isHovering ? AppTheme.surfaceHover(scheme) : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            withAnimation(BtbMotion.snappy) {
                isHovering = hovering
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if room.isLive {
            HStack(spacing: 4) {
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
                Text("直播中")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Color(hex: 0xFF3B5C), in: Capsule())
        } else {
            Text("未开播")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(.black.opacity(0.55), in: Capsule())
        }
    }
}

private struct LiveCardSkeleton: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            HStack(spacing: 7) {
                Circle()
                    .fill(AppTheme.surface(scheme))
                    .frame(width: 22, height: 22)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppTheme.surface(scheme))
                    .frame(width: 92, height: 12)
            }
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.surface(scheme))
                .frame(height: 14)
        }
        .padding(8)
    }
}

struct LiveRoomView: View {
    let room: LiveRoom

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var isTheater = {
#if DEBUG
        ProcessInfo.processInfo.environment["BTB_LIVE_THEATER"] == "1"
#else
        false
#endif
    }()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(1, min(proxy.size.width, 1600) - (isTheater ? 0 : 48))
            let isWide = proxy.size.width >= 880 && !isTheater
            let chatWidth: CGFloat = 342
            let columnSpacing: CGFloat = 18
            let playerWidth = isWide
                ? max(1, contentWidth - chatWidth - columnSpacing)
                : contentWidth
            let playerHeight = playerWidth * 9 / 16
            let theaterSize = isTheater ? theaterPlayerSize(in: proxy.size) : nil

            ScrollView {
                VStack(alignment: .leading, spacing: isTheater ? 0 : 18) {
                    if isWide {
                        HStack(alignment: .top, spacing: columnSpacing) {
                            playerColumn(
                                width: playerWidth,
                                height: playerHeight,
                                theaterSize: theaterSize
                            )
                            LiveChatPanel(room: room)
                                .frame(width: chatWidth, height: max(520, playerHeight))
                        }
                    } else {
                        playerColumn(
                            width: playerWidth,
                            height: playerHeight,
                            theaterSize: theaterSize
                        )
                        if !isTheater {
                            LiveChatPanel(room: room)
                                .frame(height: 440)
                        }
                    }
                }
                .padding(.horizontal, isTheater ? 0 : 24)
                .padding(.top, isTheater ? 0 : 16)
                .padding(.bottom, isTheater ? 0 : 44)
                .frame(maxWidth: isTheater ? CGFloat.infinity : 1600, alignment: isTheater ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isTheater ? Color.black : Color.clear)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isTheater)
            .id(room.roomID)
        }
        .background(AppTheme.background(scheme))
        .toolbar(isTheater ? .hidden : .visible, for: .windowToolbar)
        .overlay(alignment: .bottom) {
            toast
        }
        .animation(BtbMotion.snappy, value: model.toastMessage)
    }

    private func playerColumn(width: CGFloat, height: CGFloat, theaterSize: CGSize?) -> some View {
        VStack(alignment: .leading, spacing: isTheater ? 0 : 14) {
            LivePlayerView(room: room, isTheater: $isTheater)
                .frame(width: theaterSize?.width ?? width, height: theaterSize?.height ?? height)
                .frame(maxWidth: .infinity, alignment: .center)

            if !isTheater {
                LiveRoomHeader(room: room)
                descriptionCard
            }
        }
    }

    @ViewBuilder
    private var descriptionCard: some View {
        if let description = model.liveRoomInfo?.description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            SurfaceCard {
                Text(description)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
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

    @ViewBuilder
    private var toast: some View {
        if let message = model.toastMessage {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.black.opacity(0.82), in: Capsule())
                .padding(.bottom, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

private struct LiveRoomHeader: View {
    let room: LiveRoom

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private var info: LiveRoomInfo? { model.liveRoomInfo }
    private var anchorName: String {
        let name = info?.anchorName ?? room.anchorName
        return name.isEmpty ? "未知主播" : name
    }
    private var title: String {
        let value = info?.title ?? room.title
        return value.isEmpty ? "直播间" : value
    }
    private var areaName: String {
        let value = info?.areaName ?? room.areaName
        if value.isEmpty { return "" }
        if let parent = info?.parentAreaName, !parent.isEmpty, parent != value {
            return "\(parent) · \(value)"
        }
        return value
    }
    private var isLive: Bool {
        (info?.liveStatus ?? room.liveStatus) == 1
    }
    private var followers: Int {
        model.liveAttention > 0 ? model.liveAttention : (info?.attention ?? 0)
    }
    private var online: Int {
        model.livePopularity > 0 ? model.livePopularity : (info?.online ?? 0)
    }
    private var watched: Int {
        model.liveWatched > 0 ? model.liveWatched : (info?.watched ?? 0)
    }
    private var pageURL: URL {
        info?.pageURL ?? room.pageURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .lineSpacing(2)
                .foregroundStyle(AppTheme.text(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 12) {
                AvatarView(url: info?.avatarURL ?? room.avatarURL, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(anchorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                        if isLive {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 3.5, height: 3.5)
                                Text("直播中")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Color(hex: 0xFF3B5C), in: Capsule())
                        }
                        if !areaName.isEmpty {
                            Text(areaName)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .padding(.horizontal, 7)
                                .frame(height: 18)
                                .background(AppTheme.chip(scheme), in: Capsule())
                        }
                    }

                    HStack(spacing: 0) {
                        Text(statsText)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .monospacedDigit()
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    followButton
                    ShareLink(item: pageURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .frame(width: 34, height: 32)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("分享直播间")

                    Button {
                        NSWorkspace.shared.open(pageURL)
                    } label: {
                        Image(systemName: "safari")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .frame(width: 34, height: 32)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("在浏览器打开")
                }
            }
        }
    }

    private var followButton: some View {
        Button {
            Task { await model.toggleLiveFollow() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.liveIsFollowing ? "checkmark" : "heart")
                    .font(.system(size: 11, weight: .semibold))
                Text(model.liveIsFollowing ? "已关注" : "关注")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(model.liveIsFollowing ? AppTheme.secondary(scheme) : AppTheme.selectedText(scheme))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                model.liveIsFollowing ? AppTheme.chip(scheme) : AppTheme.selected(scheme),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var statsText: String {
        var parts: [String] = []
        if online > 0 { parts.append("\(LiveFormat.count(online)) 人气") }
        if followers > 0 { parts.append("\(LiveFormat.count(followers)) 粉丝") }
        if watched > 0 { parts.append("\(LiveFormat.count(watched)) 看过") }
        if let date = info?.liveStartDate, isLive {
            parts.append(LiveFormat.durationText(since: date))
        }
        return parts.joined(separator: "  ·  ")
    }
}

private struct LivePlayerView: View {
    let room: LiveRoom
    @Binding var isTheater: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var isBuffering = false
    @State private var loadFailed = false
    @State private var isHovering = false
    @State private var statusCancellable: AnyCancellable?
    @State private var timeControlCancellable: AnyCancellable?

    private var playbackURL: URL? { model.livePlayback?.playbackURL }
    private var debugHoldControls: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["BTB_LIVE_DEBUG"] == "1"
#else
        false
#endif
    }
    private var showControls: Bool {
        debugHoldControls || isHovering || !isPlaying || loadFailed || model.isLoadingLivePlay
    }
    private var currentQualityLabel: String {
        if let qn = model.liveSelectedQN,
           let quality = model.liveQualities.first(where: { $0.qn == qn }) {
            return quality.desc
        }
        if let quality = model.livePlayback?.quality {
            return quality.desc
        }
        return "清晰度"
    }

    var body: some View {
        ZStack {
            Color.black

            if let player {
                PlayerSurface(player: player)
                    .opacity(isReady ? 1 : 0)
            }

            if !isReady {
                poster
            }

            if let error = model.livePlayError {
                errorOverlay(error)
            } else if loadFailed {
                errorOverlay("直播流播放失败，请刷新重试")
            } else if !isReady || model.isLoadingLivePlay {
                loadingOverlay
            }

            if isBuffering, isReady {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            topBadges
            bottomControls
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: isTheater ? 0 : 12, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(BtbMotion.snappy) {
                isHovering = hovering
            }
        }
        .onKeyPress(.space) {
            togglePlayback()
            return .handled
        }
        .onKeyPress(KeyEquivalent("f")) {
            withAnimation(BtbMotion.snappy) {
                isTheater.toggle()
            }
            return .handled
        }
        .onExitCommand {
            guard isTheater else { return }
            withAnimation(BtbMotion.snappy) {
                isTheater = false
            }
        }
        .onChange(of: isTheater) { _, value in
            model.isTheaterActive = value
        }
        .onAppear {
            model.isTheaterActive = isTheater
        }
        .task(id: playbackURL) {
            configurePlayer()
        }
        .onDisappear {
            model.isTheaterActive = false
            statusCancellable = nil
            timeControlCancellable = nil
            player?.pause()
        }
    }

    private var poster: some View {
        ZStack {
            LiveCoverImage(url: model.liveRoomInfo?.coverURL ?? room.coverURL)
                .blur(radius: 14)
                .overlay(Color.black.opacity(0.55))
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(model.isLoadingLivePlay ? "正在连接直播…" : "正在加载直播流…")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 10) {
                Button("重试") {
                    Task { await model.refreshLivePlayback() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)

                Button("打开网页") {
                    NSWorkspace.shared.open(model.liveRoomInfo?.pageURL ?? room.pageURL)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var topBadges: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                if model.livePlayback?.playable == true {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.white)
                            .frame(width: 4, height: 4)
                        Text("直播中")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color(hex: 0xFF3B5C), in: Capsule())
                }

                if let area = model.liveRoomInfo?.areaName, !area.isEmpty {
                    Text(area)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(.black.opacity(0.42), in: Capsule())
                }

                Spacer()

                if model.livePlayback?.playable == true, model.livePopularity > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                        Text("\(LiveFormat.count(model.livePopularity)) 人气")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(.black.opacity(0.42), in: Capsule())
                }
            }
            .padding(10)
            .opacity(showControls || !isReady ? 1 : 0.55)

            Spacer()
        }
    }

    private var bottomControls: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                controlButton(isPlaying ? "pause.fill" : "play.fill", help: isPlaying ? "暂停" : "播放") {
                    togglePlayback()
                }

                controlButton(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", help: isMuted ? "取消静音" : "静音") {
                    isMuted.toggle()
                    player?.isMuted = isMuted
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(model.liveConnected ? Color(hex: 0x2ECC71) : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(model.liveConnected ? "弹幕已连接" : "弹幕连接中")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.leading, 2)

                Spacer(minLength: 8)

                if model.isLoadingLivePlay {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                qualityMenu

                controlButton("arrow.clockwise", help: "刷新直播流") {
                    Task { await model.refreshLivePlayback() }
                }

                controlButton(
                    isTheater ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    help: isTheater ? "退出全屏" : "全屏"
                ) {
                    withAnimation(BtbMotion.snappy) {
                        isTheater.toggle()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
            .padding(.top, 26)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(showControls ? 1 : 0)
            .allowsHitTesting(showControls)
            .animation(BtbMotion.snappy, value: showControls)
        }
    }

    private var qualityMenu: some View {
        Menu {
            if model.liveQualities.isEmpty {
                Text("自动")
            } else {
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
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentQualityLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(.black.opacity(0.38), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("选择清晰度")
    }

    private func controlButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 26)
                .background(.black.opacity(0.38), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func configurePlayer() {
        statusCancellable = nil
        timeControlCancellable = nil
        player?.pause()
        player = nil
        isReady = false
        loadFailed = false
        isBuffering = false

        guard let url = playbackURL else { return }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        player = newPlayer
        isPlaying = true
        newPlayer.play()

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

        timeControlCancellable = newPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { status in
                isBuffering = status == .waitingToPlayAtSpecifiedRate
                if status == .playing {
                    isPlaying = true
                }
            }
    }
}

private struct LiveChatPanel: View {
    let room: LiveRoom

    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(height: 1)

            messageList

            Rectangle()
                .fill(AppTheme.divider(scheme))
                .frame(height: 1)

            composer
        }
        .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
        }

    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("聊天")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(model.liveConnected ? Color(hex: 0x2ECC71) : Color.orange)
                    .frame(width: 6, height: 6)
                Text(model.liveConnected ? "已连接" : "连接中")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    if model.liveChatMessages.isEmpty {
                        emptyChat
                    } else {
                        ForEach(model.liveChatMessages) { message in
                            LiveChatRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.liveChatMessages.count) { _, _ in
                guard let last = model.liveChatMessages.last else { return }
                withAnimation(BtbMotion.snappy) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyChat: some View {
        VStack(spacing: 8) {
            if model.liveConnected {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                Text("暂无弹幕，稍等片刻")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            } else {
                ProgressView()
                    .controlSize(.small)
                Text("正在连接弹幕…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var composer: some View {
        if model.hasAccount {
            HStack(spacing: 8) {
                TextField("发送弹幕…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isComposerFocused)
                    .onSubmit(send)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(AppTheme.field(scheme), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
                    }

                Button(action: send) {
                    Group {
                        if model.isSendingLiveMessage {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.brand, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.isSendingLiveMessage)
                .help("发送弹幕")
            }
            .padding(10)
        } else {
            Button {
                model.presentLogin()
            } label: {
                Text("登录后参与互动")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(AppTheme.field(scheme), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(AppTheme.divider(scheme), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .padding(10)
        }
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

private struct LiveChatRow: View {
    let message: LiveChatMessage

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch message.kind {
        case .superChat:
            superChatRow
        case .gift:
            giftRow
        case .enter:
            enterRow
        case .system:
            systemRow
        case .danmaku:
            danmakuRow
        }
    }

    private var danmakuRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let medalName = message.medalName {
                medalChip(medalName)
            }
            (
                Text(message.userName + "：")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(AppTheme.secondary(scheme))
                + Text(message.text)
                    .font(.system(size: 12))
                    .foregroundColor(danmakuColor)
            )
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)

            if message.isLocal {
                Text("发送中")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.tertiary(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var superChatRow: some View {
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
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFF6A00).opacity(0.80), Color(hex: 0xFF2D55).opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var giftRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "gift.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0xFF6699))
            (
                Text(message.userName + " ")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(AppTheme.text(scheme))
                + Text(message.text)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: 0xFF6699))
            )
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFF6699).opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var enterRow: some View {
        (
            Text(message.userName + " ")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.secondary(scheme))
            + Text(message.text)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.tertiary(scheme))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemRow: some View {
        (
            Text(message.userName + " ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.secondary(scheme))
            + Text(message.text)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.accent)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func medalChip(_ name: String) -> some View {
        Text("\(name) \(message.medalLevel ?? 0)")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(AppTheme.brand)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(height: 14)
            .background(AppTheme.brand.opacity(0.12), in: Capsule())
    }

    private var danmakuColor: Color {
        guard let value = message.color, value != 0, value != 0xFFFFFF else {
            return AppTheme.text(scheme)
        }
        return Color(hex: value)
    }
}

private struct LiveCoverImage: View {
    let url: URL?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            RemoteImage(url: url)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .background(AppTheme.surface(scheme))
    }
}
