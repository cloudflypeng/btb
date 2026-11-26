import AVKit
import SwiftUI
import UIKit

struct MobilePlayerView: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @State private var isCommentsExpanded = false
    /// Owned here so the progress line under the video can read it.
    @State private var playback = MobilePlaybackController()
    /// D2: scrub-bar frames for this video.
    @State private var thumbnails = VideoThumbnails()
    /// Rotation is the app's own: the sheet rotates, and the video takes the
    /// whole screen while the phone is sideways (#7 rework).
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Pulling the picture down moves the page toward the exit; no button sits
    /// on the video any more.
    @State private var dismissOffset: CGFloat = 0

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack(alignment: .top) {
            // The strip above the video (status bar / Dynamic Island area) is
            // black, not page background.
            Color.black
                .ignoresSafeArea()
            page
                .offset(y: dismissOffset)
                // The page recedes as it is pulled away, so the drag reads as
                // "this screen is leaving", not "the video is moving".
                .scaleEffect(max(1 - dismissOffset / 4_000, 0.9))
        }
        .statusBarHidden(isLandscape)
        .onAppear { MobileOrientation.shared.setAllowsLandscape(true) }
        .onDisappear { MobileOrientation.shared.setAllowsLandscape(false) }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task(id: video.bvid) {
            #if DEBUG
            btbDebugLog("detail: task bvid=\(video.bvid)")
            #endif
            isCommentsExpanded = false
            model.openVideo(video)
            await playback.load(video: video, model: model)
            await model.loadDownloads()
            await model.loadWatchPage(for: video, force: true)
        }
        .onChange(of: playback.duration, initial: true) { _, seconds in
            guard seconds > 0 else { return }
            let cid = playback.resolved?.cid ?? video.cid.map(Int64.init)
            Task {
                await thumbnails.prepare(
                    core: model.core,
                    bvid: video.bvid,
                    cid: cid,
                    duration: seconds
                )
            }
        }
        .onDisappear {
            #if DEBUG
            btbDebugLog("detail: disappear bvid=\(video.bvid)")
            #endif
            model.closeVideo(bvid: video.bvid)
        }
    }

    private var page: some View {
        VStack(spacing: 0) {
            // Pinned straight under the Dynamic Island: the black above it is
            // the status-bar strip, and the progress line hugs its bottom edge.
            MobileVideoPlayer(
                video: video,
                playback: playback,
                thumbnails: thumbnails,
                fillsScreen: isLandscape,
                dismissOffset: $dismissOffset,
                onDismiss: closePlayer
            )
            .background(Color.black)

            if !isLandscape {
                PlayerProgressLine(playback: playback)
                    .zIndex(2)

                MobileVideoActionBar(video: video, detail: detail, playback: playback)

                videoDetails
            }
        }
        .background(AppTheme.background(scheme))
    }

    /// Leaves the page and ends the playback with it: no audio keeps running
    /// behind the home feed, no floating window.
    private func closePlayer() {
        playback.stop()
        model.closeVideo(bvid: video.bvid)
        router.dismiss()
    }

    private var videoDetails: some View {
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

    // #5: the avatar is the way into the UP's page — no separate 主页 button,
    // no "UP 主" caption — and follow is a small pill beside it.
    private var ownerRow: some View {
        HStack(spacing: 8) {
            Button {
                guard let mid = ownerMid else { return }
                router.pushUP(MobileUPRoute(mid: mid, name: ownerName, avatarURL: ownerAvatar))
            } label: {
                HStack(spacing: 8) {
                    AvatarView(url: ownerAvatar, size: 32)
                    Text(ownerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(ownerMid == nil)

            if let ownerMid {
                Button {
                    Task { await model.toggleFollow() }
                } label: {
                    Text(model.relation?.attention == true ? "已关注" : "关注")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(model.relation?.attention == true ? AppTheme.secondary(scheme) : .white)
                        .padding(.horizontal, 11)
                        .frame(height: 25)
                        .background(
                            model.relation?.attention == true ? AppTheme.chip(scheme) : AppTheme.brand,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }

    private var ownerMid: Int64? {
        model.detail?.owner?.mid ?? video.ownerMid
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
                            withAnimation(BtbMotion.snappy) {
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
                                withAnimation(BtbMotion.snappy) {
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
                .resumeProgress(for: video.bvid, cornerRadius: 9)
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
    /// Owned by `MobilePlayerView`, shared with the progress line below the video.
    let playback: MobilePlaybackController
    /// D2: frames for the scrub preview.
    var thumbnails: VideoThumbnails?
    /// Landscape: the canvas takes the whole screen instead of its 16:9 slot.
    var fillsScreen = false
    /// How far the page has been pulled down toward closing.
    @Binding var dismissOffset: CGFloat
    var onDismiss: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(MobileRouter.self) private var router

    var body: some View {
        let canvas = MobilePlayerCanvas(
            playback: playback,
            isFullscreen: fillsScreen,
            thumbnails: thumbnails,
            dismissOffset: $dismissOffset,
            onDismiss: onDismiss
        ) {
            toggleFullscreen()
        }

        // One view either way, so turning the phone never tears the player
        // down and back up; only its frame changes.
        Group {
            if fillsScreen {
                canvas.ignoresSafeArea()
            } else {
                canvas.aspectRatio(16.0 / 9.0, contentMode: .fit)
            }
        }
        .background(.black)
        .task {
            playback.onRequestPlayNext = { next in
                if router.isPlayerPresented {
                    router.play(next)
                } else {
                    router.open(next)
                }
            }
        }
        .onDisappear {
            // Still the page's own video (a pushed UP page covered it): keep
            // playing. Otherwise the page is gone or now shows something else,
            // and this playback has to end with it (#8).
            if router.isPlayerPresented, router.rootVideo?.bvid == video.bvid {
                return
            }
            playback.stop()
        }
    }

    /// #7: turning the phone is the only way into fullscreen, and turning it
    /// back is the only way out. The button does the same thing by asking for
    /// the other orientation.
    private func toggleFullscreen() {
        requestVideoOrientation(fillsScreen ? .portrait : .landscapeRight)
    }
}

struct MobilePlayerCanvas: View {
    let playback: MobilePlaybackController
    var isFullscreen: Bool
    /// D2: scrub-bar frames; the preview draws inside the canvas so it stays
    /// above the video's own layer.
    var thumbnails: VideoThumbnails?
    @Binding var dismissOffset: CGFloat
    var onDismiss: () -> Void
    var onToggleFullscreen: () -> Void

    @Environment(AppModel.self) private var model
    @State private var showControls = true
    /// D1: pinch switches the video between fit (letterboxed) and fill (cropped).
    @State private var isFill = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isSettingsPresented = false
    @State private var isComposerPresented = false

    var body: some View {
        ZStack {
            Color.black

            // The surface stays visible (not opacity 0): AVPlayerLayer only
            // reports `isReadyForDisplay` while it is actually rendering, and
            // the cover on top already hides the black frame.
            if let player = playback.player {
                VideoSurface(player: player, playback: playback, isFill: isFill)
            }

            // B2: the cached cover stands in for the first frame, then fades
            // into the video — no black flash while the stream spins up.
            if let cover = playback.video?.coverURL {
                RemoteImage(url: cover)
                    .opacity(playback.isReady ? 0 : 1)
                    .animation(BtbMotion.smooth, value: playback.isReady)
                    .allowsHitTesting(false)
            }

            PlayerGestureOverlay(
                playback: playback,
                showControls: $showControls,
                isFill: $isFill,
                onSingleTap: {
                    guard playback.isReady else { return }
                    // #6: a tap on the picture is play / pause.
                    playback.togglePlayback()
                    withAnimation(BtbMotion.snappy) { showControls = true }
                    scheduleControlsHide()
                },
                onDoubleTap: {
                    guard playback.isReady else { return }
                    withAnimation(BtbMotion.snappy) { showControls.toggle() }
                    if showControls { scheduleControlsHide() }
                },
                allowsDismissDrag: !isFullscreen,
                dismissOffset: $dismissOffset,
                onDismiss: onDismiss
            )
            .allowsHitTesting(!casting)

            if playback.danmakuEnabled, playback.isReady, !casting {
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

            if casting {
                castPanel
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

            // #6: play / pause and seeking live in the middle of the picture;
            // the bar below keeps the other functions.
            if playback.isReady, showControls, !playback.isPiPActive {
                centerControls
                    .transition(.opacity)

                controls
            }

            // D2: the scrub preview sits on top of everything the canvas
            // draws, danmaku included, but only while the bar is held.
            if playback.isScrubbing, playback.duration > 0 {
                ScrubPreview(playback: playback, thumbnails: thumbnails)
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

    private var centerControls: some View {
        HStack(spacing: isFullscreen ? 44 : 30) {
            centerButton("gobackward.15", size: isFullscreen ? 54 : 44) {
                skip(-15)
            }
            .accessibilityLabel("后退 15 秒")

            centerButton(playback.isPlaying ? "pause.fill" : "play.fill", size: isFullscreen ? 72 : 62) {
                playback.togglePlayback()
                scheduleControlsHide()
            }
            .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

            centerButton("goforward.15", size: isFullscreen ? 54 : 44) {
                skip(15)
            }
            .accessibilityLabel("前进 15 秒")
        }
        // Tapping the gaps between the centre buttons must not pause.
        .contentShape(Rectangle())
        .onTapGesture {
            showControls = true
            scheduleControlsHide()
        }
    }

    private func centerButton(
        _ icon: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.black.opacity(0.42), in: Circle())
        }
        .buttonStyle(BtbPressableStyle(scale: 0.92, haptic: false))
    }

    private func skip(_ delta: Double) {
        guard playback.duration > 0 else { return }
        playback.seekBy(delta)
        showControls = true
        scheduleControlsHide()
    }

    private var controls: some View {
        VStack {
            Spacer()

            HStack(spacing: isFullscreen ? 14 : 9) {
                Text(MobileFormat.seconds(playback.isScrubbing ? playback.scrubTime : playback.currentTime))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 42, alignment: .trailing)

                Text(MobileFormat.seconds(playback.duration))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 42, alignment: .leading)

                Spacer(minLength: 0)

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
            // The bar is a control surface: a tap on it (or on the space
            // between its buttons) keeps the controls up instead of falling
            // through to the picture's play/pause tap.
            .contentShape(Rectangle())
            .onTapGesture {
                showControls = true
                scheduleControlsHide()
            }
        }
    }

    /// The picture is on a TV: the phone shows the remote instead.
    private var casting: Bool { playback.isCasting || showFakeCast }

    /// DEBUG only: cast has to be checked against a real AirPlay route, which
    /// a simulator cannot provide. `-BTB_FAKE_CAST` draws the panel anyway.
    private var showFakeCast: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-BTB_FAKE_CAST")
        #else
        false
        #endif
    }

    /// The picture is on a TV, so the phone becomes the remote: where it is
    /// playing, and the one control that matters — bringing it back.
    private var castPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplayvideo")
                .font(.system(size: isFullscreen ? 40 : 30, weight: .light))
                .foregroundStyle(.white.opacity(0.92))

            Text(playback.castDeviceName.map { "正在投屏到 \($0)" } ?? "正在投屏")
                .font(.system(size: isFullscreen ? 17 : 14, weight: .semibold))
                .foregroundStyle(.white)

            if let title = playback.video?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Button {
                playback.stopCasting()
            } label: {
                Text("停止投屏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        // The picture's own tap layer is off while casting, so the panel takes
        // over showing / hiding the controls — play and pause still drive the TV.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(BtbMotion.snappy) { showControls.toggle() }
            if showControls { scheduleControlsHide() }
        }
        .transition(.opacity)
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
            withAnimation(BtbMotion.snappy) {
                showControls = false
            }
        }
    }
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
    /// `true` crops to fill the frame instead of letterboxing (D1 pinch).
    var isFill: Bool = false

    func makeUIView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        view.onLayerReady = { layer in
            playback?.attach(playerLayer: layer)
        }
        view.onLayerReadyForDisplay = {
            playback?.markSurfaceReady()
        }
        view.player = player
        view.isFill = isFill
        return view
    }

    func updateUIView(_ view: VideoSurfaceView, context: Context) {
        view.onLayerReady = { layer in
            playback?.attach(playerLayer: layer)
        }
        view.onLayerReadyForDisplay = {
            playback?.markSurfaceReady()
        }
        if view.player !== player {
            view.player = player
        }
        view.isFill = isFill
        view.notifyLayerReady()
    }
}

final class VideoSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var onLayerReady: ((AVPlayerLayer) -> Void)?
    /// Fires once the layer has a decoded frame to present (B2 first frame).
    var onLayerReadyForDisplay: (() -> Void)?

    private var readyObservation: NSKeyValueObservation?
    private var reportedReadyForDisplay = false

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            observeDisplayReadiness()
            notifyLayerReady()
        }
    }

    /// D1: pinch switches between fit and fill.
    var isFill: Bool = false {
        didSet {
            guard oldValue != isFill else { return }
            playerLayer.videoGravity = isFill ? .resizeAspectFill : .resizeAspect
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

    private func observeDisplayReadiness() {
        readyObservation?.invalidate()
        readyObservation = nil
        reportedReadyForDisplay = false
        #if DEBUG
        btbDebugLog("surface: observe player=\(playerLayer.player != nil) window=\(window != nil) ready=\(playerLayer.isReadyForDisplay)")
        #endif
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            #if DEBUG
            btbDebugLog("surface: kvo ready=\(layer.isReadyForDisplay) window=\(layer.superlayer != nil)")
            #endif
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.reportedReadyForDisplay else { return }
                self.reportedReadyForDisplay = true
                self.onLayerReadyForDisplay?()
            }
        }
    }

    func notifyLayerReady() {
        guard window != nil, playerLayer.player != nil else { return }
        onLayerReady?(playerLayer)
    }
}
