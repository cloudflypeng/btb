import AVKit
import SwiftUI
import UIKit

struct MobilePlayerView: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @State private var isCommentsExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            MobileVideoPlayer(video: video)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(.black)
                .zIndex(1)

            MobileVideoActionBar(video: video, detail: detail)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        titleSection
                        descriptionSection
                        ownerRow
                    }
                    Divider()
                    commentsSection
                    Divider()
                    relatedSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            Button {
                router.dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 8)
        }
        .task(id: video.bvid) {
            isCommentsExpanded = false
            model.openVideo(video)
            await model.loadDownloads()
            await model.loadWatchPage(for: video)
        }
        .onDisappear {
            model.closeVideo()
        }
    }

    private var detail: VideoInfoData? {
        model.detailBVID == video.bvid ? model.detail : nil
    }

    private var displayTitle: String {
        if let title = detail?.title, !title.isEmpty { return title }
        return video.title
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(displayTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text(scheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                if let views = detail?.stat?.view ?? Optional(video.viewCount), views > 0 {
                    Text("\(MobileFormat.count(views))次观看")
                }
                let ago = detail?.publishedAgoText ?? video.publishedAgoText
                if !ago.isEmpty {
                    Text("·")
                    Text(ago)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.secondary(scheme))
        }
    }

    private var ownerRow: some View {
        HStack(spacing: 10) {
            AvatarView(url: ownerAvatar, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(ownerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(1)
                Text("UP 主")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }

            Spacer(minLength: 8)

            if let mid = model.detail?.owner?.mid ?? video.ownerMid {
                HStack(spacing: 8) {
                    Button {
                        router.pushUP(
                            MobileUPRoute(mid: mid, name: ownerName, avatarURL: ownerAvatar)
                        )
                    } label: {
                        Text("主页")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text(scheme))
                            .padding(.horizontal, 14)
                            .frame(height: 33)
                            .background(AppTheme.chip(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await model.toggleFollow() }
                    } label: {
                        Text(model.relation?.attention == true ? "已关注" : "关注")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(model.relation?.attention == true ? AppTheme.secondary(scheme) : .white)
                            .padding(.horizontal, 16)
                            .frame(height: 33)
                            .background(
                                model.relation?.attention == true ? AppTheme.chip(scheme) : AppTheme.brand,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ownerName: String {
        if let name = detail?.owner?.name, !name.isEmpty { return name }
        return video.ownerName
    }

    private var ownerAvatar: URL? {
        MediaURL.normalize(detail?.owner?.face) ?? video.ownerFaceURL
    }

    @ViewBuilder
    private var descriptionSection: some View {
        let text = detail?.desc ?? video.description
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.secondary(scheme))
                .lineLimit(3)
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("评论")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))
                if model.commentTotal > 0 {
                    Text(MobileFormat.count(model.commentTotal))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondary(scheme))
                }
            }

            if model.isLoadingComments && model.comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else if model.comments.isEmpty {
                Text(model.hasAccount ? "还没有评论" : "登录后查看评论")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.tertiary(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(isCommentsExpanded ? model.comments : Array(model.comments.prefix(3))) { comment in
                        MobileCommentRow(comment: comment)
                    }

                    if !isCommentsExpanded, model.comments.count > 3 {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isCommentsExpanded = true
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text("展开更多评论")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.text(scheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                AppTheme.chip(scheme),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        if !model.hasAccount, model.comments.count < model.commentTotal {
                            Button {
                                model.presentLogin()
                            } label: {
                                Text("登录查看更多评论")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.brand)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(AppTheme.chip(scheme), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        } else if model.hasAccount, model.comments.count < model.commentTotal {
                            InfiniteScrollFooter(
                                isLoading: model.isLoadingComments,
                                hasMore: model.comments.count < model.commentTotal,
                                failed: model.commentsError != nil
                            ) {
                                Task { await model.loadMoreComments() }
                            }
                        }

                        if isCommentsExpanded, model.comments.count > 3 {
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    isCommentsExpanded = false
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("收起评论")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(AppTheme.secondary(scheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    AppTheme.chip(scheme),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接着看")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))

            if model.isLoadingRelated && model.relatedVideos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(model.relatedVideos) { related in
                        MobileVideoLink(video: related) {
                            MobileVideoRow(video: related)
                        }
                    }
                }
            }
        }
    }
}

private struct MobileCommentRow: View {
    let comment: VideoComment
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: comment.avatarURL, size: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(comment.author)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondary(scheme))
                        .lineLimit(1)
                    Text(comment.timeText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }

                Text(comment.message)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.text(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                if let reply = comment.replies.first {
                    HStack(alignment: .top, spacing: 5) {
                        Text(reply.author + "：")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondary(scheme))
                        Text(reply.message)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondary(scheme))
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if comment.likeCount > 0 {
                    Label(MobileFormat.count(comment.likeCount), systemImage: "hand.thumbsup")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                }
            }
        }
    }
}

struct MobileVideoRow: View {
    let video: VideoItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(url: video.coverURL)
                .frame(width: 150, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !video.durationText.isEmpty {
                        Text(video.durationText)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(5)
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(video.ownerName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondary(scheme))
                    .lineLimit(1)

                if video.viewCount > 0 {
                    Text("\(video.viewText)次观看")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.tertiary(scheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
struct MobileVideoPlayer: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @State private var playback = MobilePlaybackController()
    @State private var fullscreenHost: LandscapePlayerHost?

    var body: some View {
        MobilePlayerCanvas(playback: playback, isFullscreen: false) {
            enterFullscreen()
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .background(.black)
        .task {
            playback.onRequestPlayNext = { next in
                exitFullscreen()
                if router.isPlayerPresented {
                    router.play(next)
                } else {
                    router.open(next)
                }
            }
            await playback.load(video: video, model: model)
        }
        .onDisappear {
            if fullscreenHost == nil {
                playback.stop()
            }
        }
    }

    @MainActor
    private func enterFullscreen() {
        guard fullscreenHost == nil else { return }
        let top = UIApplication.shared.topViewController()
        guard let top else { return }
        let canvas = MobilePlayerCanvas(playback: playback, isFullscreen: true) {
            exitFullscreen()
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
        top.present(host, animated: false) {
            requestVideoOrientation(.landscapeRight)
        }
    }

    @MainActor
    private func exitFullscreen() {
        guard let host = fullscreenHost else { return }
        fullscreenHost = nil
        host.dismiss(animated: false) {
            requestVideoOrientation(.portrait)
        }
    }
}

struct MobilePlayerCanvas: View {
    let playback: MobilePlaybackController
    var isFullscreen: Bool
    var onToggleFullscreen: () -> Void

    @Environment(AppModel.self) private var model
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isSettingsPresented = false
    @State private var isComposerPresented = false

    var body: some View {
        ZStack {
            Color.black

            if let player = playback.player {
                VideoSurface(player: player, playback: playback)
                    .opacity(playback.isReady ? 1 : 0)
            }

            if !playback.isReady {
                RemoteImage(url: playback.video?.coverURL)
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            guard playback.isReady else { return }
                            playback.togglePlayback()
                            showControls = true
                            scheduleControlsHide()
                        }
                        .exclusively(
                            before: TapGesture().onEnded {
                                guard playback.isReady else { return }
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showControls.toggle()
                                }
                                if showControls { scheduleControlsHide() }
                            }
                        )
                )

            if playback.danmakuEnabled, playback.isReady {
                DanmakuOverlay(
                    player: playback.player,
                    items: playback.visibleDanmaku,
                    isEnabled: true,
                    isPlaying: playback.isPlaying,
                    opacity: playback.danmakuOpacity,
                    speed: playback.danmakuSpeed,
                    fontScale: playback.danmakuFontScale
                )
            }

            if let subtitle = playback.currentSubtitleText {
                VStack {
                    Spacer()
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.bottom, showControls ? 78 : 26)
                }
                .allowsHitTesting(false)
            }

            if playback.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if let errorMessage = playback.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button {
                        Task { await playback.retry() }
                    } label: {
                        Text("重试")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(AppTheme.brand, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let next = playback.nextVideo, let countdown = playback.autoplayCountdown {
                autoplayCard(next: next, countdown: countdown)
            }

            if playback.isReady, showControls, !playback.isPlaying,
               playback.autoplayCountdown == nil, playback.errorMessage == nil {
                Button {
                    playback.togglePlayback()
                    scheduleControlsHide()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.black.opacity(0.46), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if playback.isReady, showControls, !playback.isPiPActive {
                controls
            }

            if isFullscreen, showControls {
                VStack {
                    HStack {
                        Button {
                            onToggleFullscreen()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("退出全屏")
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 20)
                    Spacer()
                }
            }
        }
        .clipped()
        .onChange(of: playback.isReady) { _, ready in
            guard ready else { return }
            showControls = true
            scheduleControlsHide()
        }
        .onChange(of: playback.isPlaying) { _, _ in
            scheduleControlsHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hideControlsTask = nil
        }
        .sheet(isPresented: $isSettingsPresented) {
            MobilePlaybackSettingsSheet(playback: playback)
        }
        .sheet(isPresented: $isComposerPresented) {
            MobileDanmakuComposer(playback: playback)
                .environment(model)
        }
    }

    private var controls: some View {
        VStack {
            Spacer()

            HStack(spacing: isFullscreen ? 14 : 9) {
                Button {
                    playback.togglePlayback()
                    showControls = true
                    scheduleControlsHide()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isFullscreen ? 17 : 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: isFullscreen ? 34 : 26, height: isFullscreen ? 34 : 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

                Text(MobileFormat.seconds(playback.isScrubbing ? playback.scrubTime : playback.currentTime))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 42, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { playback.isScrubbing ? playback.scrubTime : playback.currentTime },
                        set: { playback.scrubTime = $0 }
                    ),
                    in: 0...max(playback.duration, 0.1),
                    onEditingChanged: { editing in
                        if editing {
                            playback.isScrubbing = true
                            showControls = true
                            hideControlsTask?.cancel()
                        } else {
                            playback.finishScrub()
                            scheduleControlsHide()
                        }
                    }
                )
                .tint(.white)
                .disabled(playback.duration <= 0)

                Text(MobileFormat.seconds(playback.duration))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 42, alignment: .leading)

                Button {
                    if model.hasAccount {
                        isComposerPresented = true
                    } else {
                        model.presentLogin()
                    }
                    showControls = true
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.system(size: isFullscreen ? 16 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: isFullscreen ? 32 : 26, height: isFullscreen ? 32 : 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("发弹幕")

                Button {
                    isSettingsPresented = true
                    showControls = true
                    hideControlsTask?.cancel()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: isFullscreen ? 16 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: isFullscreen ? 32 : 26, height: isFullscreen ? 32 : 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放设置")

                if playback.isPiPSupported {
                    Button {
                        playback.togglePiP()
                        showControls = true
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.system(size: isFullscreen ? 16 : 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: isFullscreen ? 32 : 26, height: isFullscreen ? 32 : 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("画中画")
                }

                Button {
                    onToggleFullscreen()
                    showControls = true
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: isFullscreen ? 16 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: isFullscreen ? 32 : 26, height: isFullscreen ? 32 : 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
            }
            .padding(.horizontal, isFullscreen ? 24 : 12)
            .padding(.bottom, isFullscreen ? 22 : 6)
            .frame(height: isFullscreen ? 64 : 46)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func autoplayCard(next: VideoItem, countdown: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即将播放")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
            Text(next.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(spacing: 12) {
                Text("\(countdown) 秒后自动播放")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer(minLength: 0)
                Button("取消") {
                    playback.cancelAutoplay()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                Button {
                    playback.cancelAutoplay()
                    playback.onRequestPlayNext?(next)
                } label: {
                    Text("立即播放")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(AppTheme.brand, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: 300)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard playback.isPlaying, !playback.isScrubbing, !isSettingsPresented, !isComposerPresented else {
            showControls = true
            return
        }
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled, playback.isPlaying, !playback.isScrubbing else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showControls = false
            }
        }
    }
}

final class LandscapePlayerHost: UIHostingController<AnyView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

@MainActor
func requestVideoOrientation(_ mask: UIInterfaceOrientationMask) {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    guard let scene else { return }
    scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
}

extension UIApplication {
    func topViewController() -> UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

private struct MobilePlaybackSettingsSheet: View {
    let playback: MobilePlaybackController

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var body: some View {
        @Bindable var playback = playback

        NavigationStack {
            Form {
                Section("清晰度") {
                    if let localLabel = playback.localQualityLabel {
                        HStack {
                            Text(localLabel)
                                .foregroundStyle(AppTheme.text(scheme))
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.brand)
                        }
                    } else if playback.qualities.isEmpty {
                        Text("暂无可用清晰度")
                            .foregroundStyle(AppTheme.secondary(scheme))
                    } else {
                        ForEach(playback.qualities) { quality in
                            Button {
                                Task { await playback.switchQuality(quality) }
                            } label: {
                                HStack {
                                    Text(quality.displayLabel)
                                        .foregroundStyle(AppTheme.text(scheme))
                                    Spacer()
                                    if playback.selectedQuality?.id == quality.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.brand)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("播放") {
                    Menu {
                        ForEach(rates, id: \.self) { rate in
                            Button {
                                playback.setRate(rate)
                            } label: {
                                if abs(playback.playbackRate - rate) < 0.001 {
                                    Label(rateText(rate), systemImage: "checkmark")
                                } else {
                                    Text(rateText(rate))
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("倍速")
                                .foregroundStyle(AppTheme.text(scheme))
                            Spacer()
                            Text(rateText(playback.playbackRate))
                                .foregroundStyle(AppTheme.secondary(scheme))
                        }
                    }

                    Toggle("自动连播", isOn: $playback.autoplayNext)
                }

                Section("字幕") {
                    Button {
                        Task { await playback.loadSubtitle(nil) }
                    } label: {
                        HStack {
                            Text("关闭字幕")
                                .foregroundStyle(AppTheme.text(scheme))
                            Spacer()
                            if playback.selectedSubtitle == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.brand)
                            }
                        }
                    }

                    ForEach(playback.subtitles) { subtitle in
                        Button {
                            Task { await playback.loadSubtitle(subtitle) }
                        } label: {
                            HStack {
                                Text(subtitle.displayLabel)
                                    .foregroundStyle(AppTheme.text(scheme))
                                Spacer()
                                if playback.selectedSubtitle?.id == subtitle.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.brand)
                                }
                            }
                        }
                    }
                }

                Section("弹幕") {
                    Toggle("显示弹幕", isOn: $playback.danmakuEnabled)

                    sliderRow(
                        title: "不透明度",
                        value: $playback.danmakuOpacity,
                        range: 0.2...1.0,
                        text: "\(Int((playback.danmakuOpacity * 100).rounded()))%"
                    )
                    sliderRow(
                        title: "滚动速度",
                        value: $playback.danmakuSpeed,
                        range: 0.5...2.0,
                        text: String(format: "%.1fx", playback.danmakuSpeed)
                    )
                    sliderRow(
                        title: "字号",
                        value: $playback.danmakuFontScale,
                        range: 0.6...1.6,
                        text: "\(Int((playback.danmakuFontScale * 100).rounded()))%"
                    )

                    TextField("屏蔽词，用逗号分隔", text: $playback.danmakuBlockWords)
                }
            }
            .navigationTitle("播放设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(AppTheme.text(scheme))
                Spacer()
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.secondary(scheme))
            }
            Slider(value: value, in: range)
                .tint(AppTheme.brand)
        }
        .padding(.vertical, 2)
    }

    private func rateText(_ rate: Double) -> String {
        if abs(rate - rate.rounded()) < 0.001 {
            return "\(Int(rate))x"
        }
        return String(format: "%.2gx", rate)
    }
}

private struct MobileDanmakuComposer: View {
    let playback: MobilePlaybackController

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isSending = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("发个弹幕…", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)

                HStack {
                    Text("将显示在 \(MobileFormat.seconds(playback.currentTime))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        send()
                    } label: {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("发送")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 34)
                                .background(AppTheme.brand, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .navigationTitle("发送弹幕")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(210)])
        .onAppear { isFocused = true }
    }

    private func send() {
        guard model.hasAccount else {
            model.presentLogin()
            dismiss()
            return
        }
        Task {
            isSending = true
            let sent = await playback.sendDanmaku(text)
            isSending = false
            if sent { dismiss() }
        }
    }
}

struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer
    var playback: MobilePlaybackController?

    func makeUIView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        view.onLayerReady = { layer in
            playback?.attach(playerLayer: layer)
        }
        view.player = player
        return view
    }

    func updateUIView(_ view: VideoSurfaceView, context: Context) {
        view.onLayerReady = { layer in
            playback?.attach(playerLayer: layer)
        }
        if view.player !== player {
            view.player = player
        }
        view.notifyLayerReady()
    }
}

final class VideoSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var onLayerReady: ((AVPlayerLayer) -> Void)?

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            notifyLayerReady()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyLayerReady()
    }

    func notifyLayerReady() {
        guard window != nil, playerLayer.player != nil else { return }
        onLayerReady?(playerLayer)
    }
}
