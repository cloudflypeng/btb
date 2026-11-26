import AVKit
import AppKit
import Combine
import SwiftUI

struct InlinePlayerView: View {
    let video: VideoItem
    var local: LocalPlaybackSource? = nil
    @Binding var isTheater: Bool

    @Environment(AppModel.self) private var model
    @State private var player: AVPlayer?
    @State private var session: StreamSession?
    @State private var resolved: PlayerResolveResult?
    @State private var selectedQuality: PlaybackQuality?
    @State private var selectedPage = 1
    @State private var selectedSubtitle: PlaybackSubtitle?
    @State private var subtitleCues: [SubtitleCue] = []
    @AppStorage("player.defaultRate") private var playbackRate = 1.0
    @AppStorage("player.defaultQN") private var defaultQN = 80
    @AppStorage("player.defaultCodec") private var defaultCodec = "hevc"
    @AppStorage("player.autoplayNext") private var autoplayNext = true
    @AppStorage("player.danmakuEnabled") private var danmakuEnabled = true
    @AppStorage("danmaku.opacity") private var danmakuOpacity = 0.92
    @AppStorage("danmaku.speed") private var danmakuSpeed = 1.0
    @AppStorage("danmaku.fontScale") private var danmakuFontScale = 1.0
    @AppStorage("danmaku.blockWords") private var danmakuBlockWords = ""
    @State private var danmaku: [DanmakuItem] = []
    @State private var loadedDanmakuSegments: Set<Int> = []
    @State private var danmakuDraft = ""
    @State private var showDanmakuComposer = false
    @State private var showDanmakuSettings = false
    @FocusState private var isDanmakuFieldFocused: Bool
    @State private var nextVideo: VideoItem?

    @State private var isLoading = true
    @State private var isReady = false
    @State private var isSwitchingQuality = false
    @State private var errorMessage: String?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var readyWatchdog: Task<Void, Never>?
    @State private var progressTask: Task<Void, Never>?
    @State private var isPreparing = false

    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var didReachEnd = false

    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

#if DEBUG
    private var debugHoldControls: Bool {
        ProcessInfo.processInfo.environment["BTB_PLAYER_DEBUG"] == "1"
    }

    private var debugNoProgress: Bool {
        ProcessInfo.processInfo.environment["BTB_PLAYER_NO_PROGRESS"] == "1"
    }
#else
    private var debugHoldControls: Bool { false }
    private var debugNoProgress: Bool { false }
#endif

    var body: some View {
        ZStack {
            Color.black

            if let player {
                PlayerSurface(player: player)
                    .opacity(isReady ? 1 : 0)
                if isReady, local == nil {
                    DanmakuOverlay(
                        player: player,
                        items: visibleDanmaku,
                        isEnabled: danmakuEnabled,
                        isPlaying: isPlaying,
                        opacity: danmakuOpacity,
                        speed: danmakuSpeed,
                        fontScale: danmakuFontScale
                    )
                }
            }

            if !isReady {
                poster
            }

            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在加载视频…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            if isSwitchingQuality {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在切换清晰度…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await prepare() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                }
                .padding(24)
                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: isTheater ? 0 : 12, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            guard let player, !isDanmakuFieldFocused else { return .ignored }
            togglePlayback(player)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            seekBy(-5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            seekBy(5)
            return .handled
        }
        .onKeyPress(KeyEquivalent("f")) {
            toggleTheater()
            return .handled
        }
        .onExitCommand {
            guard isTheater else { return }
            toggleTheater()
        }
        .onChange(of: isTheater) { _, value in
            model.isTheaterActive = value
        }
        .onAppear {
            model.isTheaterActive = isTheater
        }
        .onDisappear {
            model.isTheaterActive = false
        }
        .overlay(alignment: .bottom) {
            subtitleOverlay
        }
        .overlay(alignment: .bottom) {
            if showDanmakuComposer, local == nil {
                danmakuComposer
                    .padding(.horizontal, 10)
                    .padding(.bottom, showControls ? 52 : 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if isReady, let player {
                controls(for: player)
                    .opacity(showControls ? 1 : 0)
                    .allowsHitTesting(showControls)
                    .animation(.easeOut(duration: 0.18), value: showControls)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 880)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .overlay(alignment: .topLeading) {
            if showDanmakuSettings {
                danmakuSettingsPanel
                    .padding(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if let nextVideo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("即将自动播放")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                    Text(nextVideo.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Button("立即播放") {
                            model.openVideo(nextVideo)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(AppTheme.brand)
                        Button("取消") {
                            self.nextVideo = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .frame(width: 260, alignment: .leading)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(10)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isReady)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showControls = true
                scheduleControlsHide()
            case .ended:
                scheduleControlsHide()
            }
        }
        .onChange(of: isReady) { _, ready in
            guard ready else { return }
            showControls = true
            scheduleControlsHide()
        }
        .onChange(of: danmakuSpeed) { _, _ in
            assignDanmakuLanes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else { return }
            didReachEnd = true
            isPlaying = false
            showControls = true
            hideControlsTask?.cancel()
            reportProgress(event: "end", seconds: duration)
            scheduleAutoplayNext()
        }
        .task {
#if DEBUG
            if ProcessInfo.processInfo.environment["BTB_DANMAKU_SETTINGS"] == "1" {
                showDanmakuSettings = true
            }
#endif
            await prepare()
        }
        .task(id: player.map { ObjectIdentifier($0) }) {
            guard player != nil else { return }
            await monitorPlayback()
        }
        .onDisappear {
            teardown()
        }
    }

    private var poster: some View {
        ZStack {
            Color.black
            RemoteImage(url: video.coverURL)
                .overlay(.black.opacity(video.coverURL == nil ? 0 : 0.18))
        }
        .clipped()
    }

    private var subtitleOverlay: some View {
        Group {
            if let cue = activeCue {
                Text(cue.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, showControls ? 54 : 16)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: activeCue)
    }

    private var activeCue: SubtitleCue? {
        guard selectedSubtitle != nil, !subtitleCues.isEmpty else { return nil }
        return subtitleCues.first { currentTime >= $0.start && currentTime <= $0.end }
    }

    private var blockedWords: [String] {
        danmakuBlockWords
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var visibleDanmaku: [DanmakuItem] {
        let words = blockedWords
        guard !words.isEmpty else { return danmaku }
        return danmaku.filter { item in
            !words.contains { item.text.localizedCaseInsensitiveContains($0) }
        }
    }

    private func controls(for player: AVPlayer) -> some View {
        HStack(spacing: 9) {            Button {
                togglePlayback(player)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isPlaying ? "暂停" : "播放")

            if let pages = resolved?.pages, pages.count > 1 {
                partMenu(pages)
            }

            Text(timeText(currentTime))
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 44, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(duration, 0.1),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubTime = currentTime
                        showControls = true
                        hideControlsTask?.cancel()
                    } else {
                        player.seek(to: CMTime(seconds: scrubTime, preferredTimescale: 600))
                        currentTime = scrubTime
                        isScrubbing = false
                        didReachEnd = false
                        reportProgress(event: "seek", seconds: scrubTime)
                        scheduleControlsHide()
                    }
                }
            )
            .controlSize(.mini)
            .tint(.white)
            .disabled(duration <= 0)

            Text(timeText(duration))
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 44, alignment: .leading)

            Button {
                toggleMute(player)
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isMuted ? "取消静音" : "静音")

            if let qualities = resolved?.qualities, !qualities.isEmpty {
                qualityMenu(qualities)
            }

            speedMenu

            if local == nil {
                danmakuMenu
            }

            if let subtitles = resolved?.subtitles, !subtitles.isEmpty {
                subtitleMenu(subtitles)
            }

            Button {
                toggleTheater()
            } label: {
                Image(systemName: isTheater ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isTheater ? "退出影院模式 (F)" : "影院模式 (F)")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onHover { hovering in
            if hovering {
                showControls = true
                hideControlsTask?.cancel()
            } else {
                scheduleControlsHide()
            }
        }
    }

    private func partMenu(_ pages: [PlaybackPage]) -> some View {
        Menu {
            ForEach(pages) { part in
                Button {
                    Task { await switchPage(part.page) }
                } label: {
                    if selectedPage == part.page {
                        Label(partTitle(part), systemImage: "checkmark")
                    } else {
                        Text(partTitle(part))
                    }
                }
            }
        } label: {
            controlLabel("P\(selectedPage)", systemName: "list.number")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("分P")
    }

    private func partTitle(_ part: PlaybackPage) -> String {
        let title = part.part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "P\(part.page)" : "P\(part.page) \(title)"
    }

    private func qualityMenu(_ qualities: [PlaybackQuality]) -> some View {        Menu {
            ForEach(qualities) { quality in
                Button {
                    Task { await switchQuality(quality) }
                } label: {
                    if selectedQuality?.id == quality.id {
                        Label(quality.displayLabel, systemImage: "checkmark")
                    } else {
                        Text(quality.displayLabel)
                    }
                }
            }
        } label: {
            controlLabel(selectedQuality?.label ?? "清晰度", systemName: "display")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("清晰度与编码")
    }

    private var danmakuMenu: some View {
        Menu {
            Toggle("显示弹幕", isOn: $danmakuEnabled)
            Button("发送弹幕…") {
                showDanmakuComposer = true
                isDanmakuFieldFocused = true
            }
            Divider()
            Button("弹幕设置…") {
                withAnimation(.easeOut(duration: 0.16)) {
                    showDanmakuSettings.toggle()
                }
            }
        } label: {
            Image(systemName: danmakuEnabled ? "text.bubble.fill" : "text.bubble")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("弹幕")
    }

    private var danmakuSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("弹幕设置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showDanmakuSettings = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Toggle("显示弹幕", isOn: $danmakuEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(AppTheme.brand)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))

            danmakuSliderRow(
                title: "不透明度",
                value: $danmakuOpacity,
                range: 0.2...1,
                step: 0.05,
                valueText: "\(Int((danmakuOpacity * 100).rounded()))%"
            )
            danmakuSliderRow(
                title: "速度",
                value: $danmakuSpeed,
                range: 0.5...2,
                step: 0.1,
                valueText: String(format: "%.1fx", danmakuSpeed)
            )
            danmakuSliderRow(
                title: "字号",
                value: $danmakuFontScale,
                range: 0.7...1.5,
                step: 0.05,
                valueText: "\(Int((danmakuFontScale * 100).rounded()))%"
            )

            TextField("屏蔽词，用逗号分隔", text: $danmakuBlockWords)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Button {
                showDanmakuSettings = false
                showDanmakuComposer = true
                isDanmakuFieldFocused = true
            } label: {
                Label("发送弹幕", systemImage: "paperplane")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(AppTheme.brand.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 286)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }

    private func danmakuSliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .controlSize(.mini)
                .tint(.white)
            Text(valueText)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var danmakuComposer: some View {
        HStack(spacing: 8) {
            TextField("发个弹幕…", text: $danmakuDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .focused($isDanmakuFieldFocused)
                .onSubmit(sendDanmaku)
            Button("发送", action: sendDanmaku)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AppTheme.brand)
                .disabled(danmakuDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button {
                showDanmakuComposer = false
                isDanmakuFieldFocused = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    private var speedMenu: some View {        Menu {
            ForEach(rates, id: \.self) { rate in
                Button {
                    setRate(rate)
                } label: {
                    if abs(playbackRate - rate) < 0.001 {
                        Label(rateText(rate), systemImage: "checkmark")
                    } else {
                        Text(rateText(rate))
                    }
                }
            }
        } label: {
            controlLabel(rateText(playbackRate), systemName: "speedometer")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("播放速度")
    }

    private func subtitleMenu(_ subtitles: [PlaybackSubtitle]) -> some View {
        Menu {
            Button("关闭字幕") {
                selectedSubtitle = nil
                subtitleCues = []
            }
            Divider()
            ForEach(subtitles) { subtitle in
                Button {
                    Task { await loadSubtitle(subtitle) }
                } label: {
                    if selectedSubtitle?.id == subtitle.id {
                        Label(subtitle.displayLabel, systemImage: "checkmark")
                    } else {
                        Text(subtitle.displayLabel)
                    }
                }
            }
        } label: {
            controlLabel(selectedSubtitle?.displayLabel ?? "字幕", systemName: "captions.bubble")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("字幕")
    }

    private func controlLabel(_ text: String, systemName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 5)
        .frame(height: 24)
        .contentShape(Rectangle())
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func rateText(_ rate: Double) -> String {
        if abs(rate - rate.rounded()) < 0.001 {
            return "\(Int(rate))x"
        }
        return String(format: "%.2gx", rate)
    }

    private func togglePlayback(_ player: AVPlayer) {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            showControls = true
            hideControlsTask?.cancel()
            reportProgress(event: "pause", seconds: currentTime)
        } else {
            if didReachEnd || (duration > 0 && currentTime >= duration - 0.2) {
                player.seek(to: .zero)
                currentTime = 0
                didReachEnd = false
            }
            player.play()
            player.rate = Float(playbackRate)
            isPlaying = true
            showControls = true
            scheduleControlsHide()
        }
    }

    private func toggleMute(_ player: AVPlayer) {
        player.isMuted.toggle()
        isMuted = player.isMuted
        showControls = true
        scheduleControlsHide()
    }

    private func seekBy(_ delta: Double) {
        guard let player, duration > 0 else { return }
        let target = min(max(currentTime + delta, 0), max(duration - 0.5, 0))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        didReachEnd = false
        reportProgress(event: "seek", seconds: target)
        showControls = true
        scheduleControlsHide()
    }

    private func scheduleAutoplayNext() {
        guard local == nil, autoplayNext else { return }
        guard let next = model.relatedVideos.first(where: { $0.bvid != video.bvid }) else { return }
        nextVideo = next
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, didReachEnd, nextVideo?.bvid == next.bvid else { return }
            nextVideo = nil
            model.openVideo(next)
        }
    }

    private func setRate(_ rate: Double) {
        playbackRate = rate
        guard let player else { return }
        player.defaultRate = Float(rate)
        if player.timeControlStatus == .playing {
            player.rate = Float(rate)
        }
        showControls = true
        scheduleControlsHide()
    }

    private func toggleTheater() {
        withAnimation(.easeInOut(duration: 0.24)) {
            isTheater.toggle()
        }
        showControls = true
        scheduleControlsHide()
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard isPlaying, !isScrubbing, !debugHoldControls else {
            showControls = true
            return
        }
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled, isPlaying, !isScrubbing else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showControls = false
            }
        }
    }

    private func monitorPlayback() async {
        while !Task.isCancelled {
            updatePlaybackState()
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func updatePlaybackState() {
        guard let player else { return }

        let playing = player.timeControlStatus == .playing
        if playing != isPlaying {
            if isPlaying && !playing && isReady && !didReachEnd {
                reportProgress(event: "pause", seconds: currentTime)
            }
            isPlaying = playing
            if !playing {
                showControls = true
            }
        }
        isMuted = player.isMuted

        guard !isScrubbing else { return }
        let seconds = player.currentTime().seconds
        if seconds.isFinite {
            currentTime = max(0, seconds)
        }
        if let item = player.currentItem {
            let total = item.duration.seconds
            if total.isFinite, total > 0 {
                duration = total
            }
        }
        ensureDanmakuSegment(for: currentTime)
    }

    private func prepare() async {
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        hideControlsTask?.cancel()
        progressTask?.cancel()
        progressTask = nil
        isLoading = true
        isReady = false
        isSwitchingQuality = false
        errorMessage = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isMuted = false
        isScrubbing = false
        scrubTime = 0
        showControls = true
        didReachEnd = false
        clearStatusObservation()
        player?.pause()
        player = nil
        if let oldSession = session {
            session = nil
            await model.stopStream(sessionID: oldSession.sessionID)
        }
        resolved = nil
        selectedQuality = nil
        selectedSubtitle = nil
        subtitleCues = []
        danmaku = []
        loadedDanmakuSegments = []
        showDanmakuComposer = false
        danmakuDraft = ""

        if let local {
            prepareLocal(local)
            return
        }

        do {
            let result = try await model.resolvePlayback(
                for: video,
                page: selectedPage,
                qn: Int64(defaultQN),
                codec: defaultCodec,
                cid: video.cid.map(Int64.init)
            )
            if Task.isCancelled { return }
            resolved = result
            if let index = result.pages.firstIndex(where: { $0.cid == result.cid }) {
                selectedPage = index + 1
            } else {
                selectedPage = result.page ?? selectedPage
            }
            duration = Double(result.durationMS ?? 0) / 1000
            ensureDanmakuSegment(for: 0)

            guard result.canPlay, let quality = preferredQuality(from: result) else {
                isLoading = false
                errorMessage = result.isPreview == true ? "当前视频为预览片段，暂不可播放" : "当前视频暂不可播放"
                return
            }
            selectedQuality = quality
            let startAt = initialResume(from: result)
            try await load(quality: quality, startAt: startAt, autoplay: true)
            startProgressLoop()
#if DEBUG
            if debugHoldControls, let subtitle = result.subtitles.first {
                await loadSubtitle(subtitle)
            }
#endif
        } catch {
            if Task.isCancelled { return }
            isLoading = false
            isReady = false
            errorMessage = playbackErrorMessage(error)
        }
    }

    private func prepareLocal(_ source: LocalPlaybackSource) {
        duration = Double(source.durationMS ?? 0) / 1000
        let item = AVPlayerItem(url: source.masterURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.allowsExternalPlayback = true
        newPlayer.isMuted = isMuted
        newPlayer.defaultRate = Float(playbackRate)
        player = newPlayer
        watch(item: item, seekTo: 0, autoplay: true)
    }

    private func load(quality: PlaybackQuality, startAt: Double, autoplay: Bool) async throws {
        clearStatusObservation()
        guard let resolved else { throw BBCoreError.invalidResponse }
        let oldSession = session
        let oldPlayer = player
        oldPlayer?.pause()

        let stream = try await model.startStream(
            bvid: resolved.bvid,
            cid: resolved.cid,
            qn: quality.qn,
            codec: quality.codec ?? "hevc"
        )
        if Task.isCancelled {
            await model.stopStream(sessionID: stream.sessionID)
            return
        }
        guard let url = stream.playbackURL else {
            await model.stopStream(sessionID: stream.sessionID)
            throw BBCoreError.invalidResponse
        }

        if let actualCodec = stream.video?.codecid,
           actualCodec != quality.codecid,
           let actual = resolved.qualities.first(where: { $0.qn == quality.qn && $0.codecid == actualCodec }) {
            selectedQuality = actual
        }
        if let durationMS = stream.durationMS, durationMS > 0 {
            duration = Double(durationMS) / 1000
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.allowsExternalPlayback = true
        newPlayer.isMuted = isMuted
        newPlayer.defaultRate = Float(playbackRate)
        session = stream
        player = newPlayer
        isSwitchingQuality = oldPlayer != nil
        watch(item: item, seekTo: startAt, autoplay: autoplay)

        if let oldSession {
            Task { await model.stopStream(sessionID: oldSession.sessionID) }
        }
    }

    private func switchQuality(_ quality: PlaybackQuality) async {
        guard selectedQuality?.id != quality.id else { return }
        let previous = selectedQuality
        let resume = currentTime
        let wasPlaying = isPlaying
        selectedQuality = quality
        do {
            try await load(quality: quality, startAt: resume, autoplay: wasPlaying)
        } catch {
            selectedQuality = previous
            isSwitchingQuality = false
            model.showToast("切换清晰度失败")
            if wasPlaying {
                player?.play()
                player?.rate = Float(playbackRate)
                isPlaying = true
            }
        }
    }

    private func switchPage(_ page: Int) async {
        guard page != selectedPage else { return }
        let previousPage = selectedPage
        let previousQuality = selectedQuality
        let wasPlaying = isPlaying
        selectedPage = page
        do {
            let result = try await model.resolvePlayback(
                for: video,
                page: page,
                qn: Int64(defaultQN),
                codec: defaultCodec
            )
            guard result.canPlay, let quality = matchingQuality(previousQuality, in: result) else {
                throw BBCoreError.invalidResponse
            }
            resolved = result
            selectedQuality = quality
            duration = Double(result.durationMS ?? 0) / 1000
            selectedSubtitle = nil
            subtitleCues = []
            danmaku = []
            loadedDanmakuSegments = []
            ensureDanmakuSegment(for: 0)
            try await load(quality: quality, startAt: 0, autoplay: wasPlaying)
        } catch {
            selectedPage = previousPage
            selectedQuality = previousQuality
            isSwitchingQuality = false
            model.showToast("切换分P失败")
            if wasPlaying {
                player?.play()
                player?.rate = Float(playbackRate)
                isPlaying = true
            }
        }
    }

    private func matchingQuality(_ previous: PlaybackQuality?, in result: PlayerResolveResult) -> PlaybackQuality? {
        if let previous,
           let exact = result.qualities.first(where: { $0.qn == previous.qn && $0.codec == previous.codec }) {
            return exact
        }
        if let previous,
           let sameQuality = result.qualities.first(where: { $0.qn == previous.qn }) {
            return sameQuality
        }
        return preferredQuality(from: result)
    }

    private func loadSubtitle(_ subtitle: PlaybackSubtitle) async {
        guard let url = subtitle.url else { return }
        do {
            let cues = try await model.fetchSubtitleCues(url: url)
            selectedSubtitle = subtitle
            subtitleCues = cues
            if cues.isEmpty {
                model.showToast("该字幕暂无内容")
            }
        } catch {
            model.showToast("字幕加载失败")
        }
    }

    private func preferredQuality(from result: PlayerResolveResult) -> PlaybackQuality? {
        let setting = Int64(defaultQN)
        let target = min(result.defaultQN ?? setting, setting)
        let sorted = result.qualities.sorted { $0.qn > $1.qn }
        let eligible = sorted.filter { $0.qn <= target }
        let preferredCodec = result.defaultCodec ?? defaultCodec
        if let best = eligible.first {
            if let exact = eligible.first(where: { $0.qn == best.qn && $0.codec == preferredCodec }) {
                return exact
            }
            return best
        }
        return sorted.first
    }

    /// Cloud history merged with this Mac's local mark (B4).
    private func initialResume(from result: PlayerResolveResult) -> Double {
        let total = Double(result.durationMS ?? 0) / 1000
        let local = model.playbackProgress.resumeSeconds(for: result.bvid, cid: result.cid)
        let resume = max(result.resumeSeconds, local)
        guard resume > 3 else { return 0 }
        guard total <= 0 || resume < total - 2 else { return 0 }
        return resume
    }

    /// KVO instead of a 200 ms poll — the poll cost ~100 ms of first-frame delay (B2).
    private func watch(item: AVPlayerItem, seekTo: Double, autoplay: Bool) {
        clearStatusObservation()
        isLoading = true
        item.preferredForwardBufferDuration = 1.0

        let token = ObjectIdentifier(item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { observed, _ in
            let status = observed.status
            Task { @MainActor in
                handleItemStatus(status, token: token, seekTo: seekTo, autoplay: autoplay)
            }
        }

        readyWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            guard !Task.isCancelled, !isReady, errorMessage == nil else { return }
            player?.pause()
            isLoading = false
            isSwitchingQuality = false
            errorMessage = "视频加载超时，请重试"
        }
    }

    private func handleItemStatus(
        _ status: AVPlayerItem.Status,
        token: ObjectIdentifier,
        seekTo: Double,
        autoplay: Bool
    ) {
        guard let player, let item = player.currentItem, ObjectIdentifier(item) == token else { return }
        switch status {
        case .readyToPlay:
            clearStatusObservation()
            isLoading = false
            isReady = true
            isSwitchingQuality = false
            Perf.end("video.firstFrame", "platform=mac")
            if seekTo > 1 {
                player.seek(to: CMTime(seconds: seekTo, preferredTimescale: 600))
                currentTime = seekTo
            }
            if autoplay {
                player.playImmediately(atRate: Float(playbackRate))
                isPlaying = true
            }
            reportProgress(event: seekTo > 1 ? "seek" : "start", seconds: seekTo)
        case .failed:
            clearStatusObservation()
            player.pause()
            isLoading = false
            isSwitchingQuality = false
            errorMessage = "视频加载失败，请稍后重试"
            #if DEBUG
            btbDebugLog("play: mac item failed \(String(describing: item.error))")
            #endif
        default:
            break
        }
    }

    private func clearStatusObservation() {
        readyWatchdog?.cancel()
        readyWatchdog = nil
        statusObservation?.invalidate()
        statusObservation = nil
    }

    private func seek(player: AVPlayer?, to seconds: Double) async {
        guard let player else { return }
        await withCheckedContinuation { continuation in
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { _ in
                continuation.resume()
            }
        }
        currentTime = seconds
    }

    private func startProgressLoop() {
        guard progressTask == nil else { return }
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled, isReady, isPlaying, player != nil else { continue }
                reportProgress(event: "heartbeat", seconds: currentTime)
            }
        }
    }

    private func ensureDanmakuSegment(for seconds: Double) {
        guard danmakuEnabled,
              let resolution = resolved,
              seconds.isFinite,
              seconds >= 0 else { return }
        let segment = Int(seconds / 360) + 1
        guard !loadedDanmakuSegments.contains(segment) else { return }
        loadedDanmakuSegments.insert(segment)
        let cid = resolution.cid
        Task {
            do {
                let items = try await model.fetchDanmaku(cid: cid, segment: segment)
                guard !Task.isCancelled, resolved?.cid == cid else { return }
                let existing = Set(danmaku.map(\.id))
                danmaku.append(contentsOf: items.filter { !existing.contains($0.id) })
                danmaku.sort { $0.start < $1.start }
                assignDanmakuLanes()
            } catch {
                loadedDanmakuSegments.remove(segment)
            }
        }
    }

    private func assignDanmakuLanes() {
        let scrollLaneCount = 10
        let staticLaneCount = 3
        var scrollFreeAt = Array(repeating: 0.0, count: scrollLaneCount)
        var topFreeAt = Array(repeating: 0.0, count: staticLaneCount)
        var bottomFreeAt = Array(repeating: 0.0, count: staticLaneCount)
        let order = danmaku.indices.sorted { danmaku[$0].start < danmaku[$1].start }
        let scrollLifetime = 8.0 / max(0.25, danmakuSpeed)
        for index in order {
            let item = danmaku[index]
            let width = max(40, item.widthUnits * item.fontSize)
            if item.mode == 1 {
                // Free a lane only after the previous comment's tail has cleared a narrow viewport.
                let clearance = scrollLifetime * (width + 24) / (400 + width)
                var chosen = -1
                var earliest = Double.greatestFiniteMagnitude
                var earliestLane = 0
                for lane in 0..<scrollLaneCount {
                    if scrollFreeAt[lane] <= item.start {
                        chosen = lane
                        break
                    }
                    if scrollFreeAt[lane] < earliest {
                        earliest = scrollFreeAt[lane]
                        earliestLane = lane
                    }
                }
                if chosen < 0 {
                    guard earliest - item.start < 0.35 else {
                        danmaku[index].lane = -1
                        continue
                    }
                    chosen = earliestLane
                }
                danmaku[index].lane = chosen
                scrollFreeAt[chosen] = item.start + clearance
            } else {
                let isTop = item.mode == 5
                var freeAt = isTop ? topFreeAt : bottomFreeAt
                var chosen = -1
                for lane in 0..<staticLaneCount where freeAt[lane] <= item.start {
                    chosen = lane
                    break
                }
                guard chosen >= 0 else {
                    danmaku[index].lane = -1
                    continue
                }
                danmaku[index].lane = chosen
                freeAt[chosen] = item.start + 4.0
                if isTop {
                    topFreeAt = freeAt
                } else {
                    bottomFreeAt = freeAt
                }
            }
        }
    }

    private func sendDanmaku() {
        let text = danmakuDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let resolved else { return }
        let start = currentTime
        Task {
            let sent = await model.sendDanmaku(
                cid: resolved.cid,
                bvid: resolved.bvid,
                progressMS: Int64(max(start, 0) * 1000),
                content: text
            )
            guard sent else { return }
            danmaku.append(
                DanmakuItem(
                    id: "local-\(UUID().uuidString)",
                    start: start,
                    mode: 1,
                    text: text
                )
            )
            danmaku.sort { $0.start < $1.start }
            assignDanmakuLanes()
            danmakuDraft = ""
            showDanmakuComposer = false
            isDanmakuFieldFocused = false
        }
    }

    private func reportProgress(event: String, seconds: Double) {
        guard let resolved else { return }
        if !debugNoProgress {
            model.playbackProgress.record(
                bvid: video.bvid,
                cid: resolved.cid,
                seconds: event == "end" ? max(duration, 0) : seconds,
                duration: duration
            )
        }
        guard !debugNoProgress, isReady || event == "end" else { return }
        let milliseconds = Int64(max(seconds, 0) * 1000)
        Task {
            await model.reportPlaybackProgress(
                for: video,
                cid: resolved.cid,
                progressMS: event == "end" ? -1 : milliseconds,
                event: event
            )
        }
    }

    private func playbackErrorMessage(_ error: Error) -> String {
        if case let BBCoreError.rpc(_, message) = error, !message.isEmpty {
            return message
        }
        return "视频加载失败，请稍后重试"
    }

    private func teardown() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
        clearStatusObservation()
        progressTask?.cancel()
        progressTask = nil
        if isReady, !didReachEnd {
            reportProgress(event: "pause", seconds: currentTime)
        }
        player?.pause()
        player = nil
        if let session {
            self.session = nil
            Task { await model.stopStream(sessionID: session.sessionID) }
        }
    }
}
