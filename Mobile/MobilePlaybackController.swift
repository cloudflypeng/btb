import AVFoundation
import AVKit
import SwiftUI

@MainActor
@Observable
final class MobilePlaybackController: NSObject {
    private(set) var video: VideoItem?
    private(set) var resolved: PlayerResolveResult?
    private(set) var selectedQuality: PlaybackQuality?
    private(set) var player: AVPlayer?
    private(set) var sessionID: String?

    private(set) var isLoading = false
    private(set) var isReady = false
    private(set) var errorMessage: String?

    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var didReachEnd = false
    var isScrubbing = false {
        didSet {
            if isScrubbing { scrubTime = currentTime }
        }
    }
    var scrubTime: Double = 0

    var isMuted = false {
        didSet { player?.isMuted = isMuted }
    }

    var playbackRate: Double {
        didSet {
            UserDefaults.standard.set(playbackRate, forKey: "player.defaultRate")
            applyRate()
        }
    }

    var danmakuEnabled: Bool {
        didSet {
            UserDefaults.standard.set(danmakuEnabled, forKey: "player.danmakuEnabled")
            if danmakuEnabled { ensureDanmakuSegment(for: currentTime) }
        }
    }
    var danmakuOpacity: Double {
        didSet { UserDefaults.standard.set(danmakuOpacity, forKey: "danmaku.opacity") }
    }
    var danmakuSpeed: Double {
        didSet { UserDefaults.standard.set(danmakuSpeed, forKey: "danmaku.speed") }
    }
    var danmakuFontScale: Double {
        didSet { UserDefaults.standard.set(danmakuFontScale, forKey: "danmaku.fontScale") }
    }
    var danmakuBlockWords: String {
        didSet { UserDefaults.standard.set(danmakuBlockWords, forKey: "danmaku.blockWords") }
    }
    var autoplayNext: Bool {
        didSet { UserDefaults.standard.set(autoplayNext, forKey: "player.autoplayNext") }
    }

    private(set) var danmakuItems: [DanmakuItem] = []
    private(set) var loadedDanmakuSegments: Set<Int> = []
    private(set) var selectedSubtitle: PlaybackSubtitle?
    private(set) var subtitleCues: [SubtitleCue] = []
    private(set) var nextVideo: VideoItem?
    private(set) var autoplayCountdown: Int?
    private(set) var isPiPActive = false
    private(set) var localJob: DownloadJob?

    var isLocalPlayback: Bool { localJob != nil }

    var localQualityLabel: String? {
        guard let localJob else { return nil }
        return "已下载 · \(localJob.qualityText)"
    }

    @ObservationIgnored var onRequestPlayNext: ((VideoItem) -> Void)?
    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private let defaultQN: Int
    @ObservationIgnored private let defaultCodec: String
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var autoplayTask: Task<Void, Never>?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var resumeAfterInterruption = false
    @ObservationIgnored private var pipController: AVPictureInPictureController?

    override init() {
        let defaults = UserDefaults.standard
        let rate = defaults.double(forKey: "player.defaultRate")
        playbackRate = rate > 0 ? min(max(rate, 0.5), 3.0) : 1.0
        danmakuEnabled = defaults.object(forKey: "player.danmakuEnabled") as? Bool ?? true
        let opacity = defaults.double(forKey: "danmaku.opacity")
        danmakuOpacity = opacity > 0 ? min(max(opacity, 0.2), 1.0) : 0.92
        let speed = defaults.double(forKey: "danmaku.speed")
        danmakuSpeed = speed > 0 ? min(max(speed, 0.5), 2.0) : 1.0
        let fontScale = defaults.double(forKey: "danmaku.fontScale")
        danmakuFontScale = fontScale > 0 ? min(max(fontScale, 0.6), 1.6) : 1.0
        danmakuBlockWords = defaults.string(forKey: "danmaku.blockWords") ?? ""
        autoplayNext = defaults.object(forKey: "player.autoplayNext") as? Bool ?? true
        let storedQN = defaults.integer(forKey: "player.defaultQN")
        defaultQN = storedQN > 0 ? storedQN : 80
        let codec = defaults.string(forKey: "player.defaultCodec") ?? "hevc"
        defaultCodec = codec.isEmpty ? "hevc" : codec
        isMuted = defaults.bool(forKey: "player.muted")
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAudioInterruption(notification)
            }
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if resumeAfterInterruption, options.contains(.shouldResume), isReady, !didReachEnd {
                configureAudioSession()
                player?.playImmediately(atRate: Float(playbackRate))
            }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    var qualities: [PlaybackQuality] {
        (resolved?.qualities ?? []).sorted { $0.qn > $1.qn }
    }

    var subtitles: [PlaybackSubtitle] {
        resolved?.subtitles ?? []
    }

    var isPiPSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    var currentSubtitleText: String? {
        guard selectedSubtitle != nil else { return nil }
        return subtitleCues.first { currentTime >= $0.start && currentTime <= $0.end }?.text
    }

    var visibleDanmaku: [DanmakuItem] {
        guard danmakuEnabled else { return [] }
        let words = blockedWords
        guard !words.isEmpty else { return danmakuItems }
        return danmakuItems.filter { item in
            !words.contains { item.text.localizedCaseInsensitiveContains($0) }
        }
    }

    private var blockedWords: [String] {
        danmakuBlockWords
            .split(whereSeparator: { ",，;；".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func load(video: VideoItem, model: AppModel) async {
        if self.video?.bvid == video.bvid, isReady || isLoading { return }
        self.video = video
        self.model = model
        await prepare()
    }

    func retry() async {
        guard video != nil, model != nil else { return }
        await prepare()
    }

    private func prepare() async {
        guard let video, let model else { return }
        teardownPlayer()
        isLoading = true
        isReady = false
        errorMessage = nil
        currentTime = 0
        duration = 0
        didReachEnd = false
        isPlaying = false
        isScrubbing = false
        scrubTime = 0
        resolved = nil
        selectedQuality = nil
        selectedSubtitle = nil
        subtitleCues = []
        danmakuItems = []
        loadedDanmakuSegments = []
        nextVideo = nil
        autoplayCountdown = nil
        localJob = nil
        startMonitor()

        if let job = model.downloadJob(bvid: video.bvid, cid: video.cid.map(Int64.init)),
           job.isCompleted,
           let url = await model.downloadPlaybackURL(for: job) {
            guard !Task.isCancelled, self.video?.bvid == video.bvid else { return }
            localJob = job
            duration = Double(job.durationMS ?? 0) / 1000
            configureAudioSession()
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            newPlayer.isMuted = isMuted
            newPlayer.defaultRate = Float(playbackRate)
            player = newPlayer
            watch(item: item, seekTo: 0, autoplay: true)
            return
        }

        do {
            let result = try await model.resolvePlayback(
                for: video,
                page: 1,
                qn: Int64(defaultQN),
                codec: defaultCodec,
                cid: video.cid.map(Int64.init)
            )
            guard !Task.isCancelled, self.video?.bvid == video.bvid else { return }
            resolved = result
            duration = Double(result.durationMS ?? 0) / 1000

            guard result.canPlay, let quality = preferredQuality(from: result) else {
                isLoading = false
                errorMessage = result.isPreview == true ? "当前视频为预览片段，暂不可播放" : "当前视频暂不可播放"
                return
            }
            selectedQuality = quality
            try await load(quality: quality, startAt: initialResume(from: result), autoplay: true)
            startProgressLoop()
            ensureDanmakuSegment(for: 0)
        } catch {
            if Task.isCancelled { return }
            isLoading = false
            isReady = false
            errorMessage = playbackMessage(error)
        }
    }

    private func load(quality: PlaybackQuality, startAt: Double, autoplay: Bool) async throws {
        guard let model, let resolved else { throw BBCoreError.invalidResponse }
        statusTask?.cancel()
        statusTask = nil
        removeEndObserver()
        let oldSession = sessionID
        player?.pause()

        let stream = try await model.startStream(
            bvid: resolved.bvid,
            cid: resolved.cid,
            qn: quality.qn,
            codec: quality.codec ?? "hevc"
        )
        guard !Task.isCancelled else {
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

        configureAudioSession()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.allowsExternalPlayback = true
        newPlayer.isMuted = isMuted
        newPlayer.defaultRate = Float(playbackRate)
        player = newPlayer
        sessionID = stream.sessionID
        watch(item: item, seekTo: startAt, autoplay: autoplay)

        if let oldSession {
            Task { await model.stopStream(sessionID: oldSession) }
        }
    }

    private func watch(item: AVPlayerItem, seekTo: Double, autoplay: Bool) {
        statusTask = Task { @MainActor in
            for _ in 0..<100 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                guard player?.currentItem === item else { return }
                if item.status == .readyToPlay {
                    if seekTo > 1 {
                        await seek(to: seekTo)
                    }
                    isLoading = false
                    isReady = true
                    didReachEnd = false
                    Perf.end("video.firstFrame", "platform=ios")
                    if autoplay {
                        player?.play()
                        applyRate()
                        isPlaying = true
                    }
                    reportProgress(event: seekTo > 1 ? "seek" : "start", seconds: seekTo)
                    observeEnd(of: item)
                    return
                }
                if item.status == .failed {
                    player?.pause()
                    isLoading = false
                    isReady = false
                    errorMessage = "视频加载失败，请稍后重试"
                    return
                }
            }
            if !Task.isCancelled, item.status != .readyToPlay {
                player?.pause()
                isLoading = false
                isReady = false
                errorMessage = "视频加载超时，请重试"
            }
        }
    }

    func switchQuality(_ quality: PlaybackQuality) async {
        guard selectedQuality?.id != quality.id, isReady else { return }
        let previous = selectedQuality
        let resume = currentTime
        let wasPlaying = isPlaying
        selectedQuality = quality
        do {
            try await load(quality: quality, startAt: resume, autoplay: wasPlaying)
        } catch {
            selectedQuality = previous
            if wasPlaying {
                player?.play()
                applyRate()
                isPlaying = true
            }
        }
    }

    func setRate(_ rate: Double) {
        playbackRate = rate
    }

    func applyRate() {
        guard let player else { return }
        player.defaultRate = Float(playbackRate)
        if player.timeControlStatus == .playing {
            player.rate = Float(playbackRate)
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            reportProgress(event: "pause", seconds: currentTime)
        } else {
            if didReachEnd || (duration > 0 && currentTime >= duration - 0.2) {
                player.seek(to: .zero)
                currentTime = 0
                didReachEnd = false
                cancelAutoplay()
            }
            player.play()
            applyRate()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) async {
        guard let player else { return }
        let target = min(max(seconds, 0), max(duration - 0.2, 0))
        await withCheckedContinuation { continuation in
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { _ in
                continuation.resume()
            }
        }
        currentTime = target
        didReachEnd = false
        reportProgress(event: "seek", seconds: target)
    }

    func seekBy(_ delta: Double) {
        guard let player else { return }
        let target = min(max(currentTime + delta, 0), max(duration - 0.5, 0))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        didReachEnd = false
        reportProgress(event: "seek", seconds: target)
    }

    func finishScrub() {
        guard isScrubbing else { return }
        let target = scrubTime
        isScrubbing = false
        Task { await seek(to: target) }
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: "player.muted")
    }

    func loadSubtitle(_ subtitle: PlaybackSubtitle?) async {
        guard let subtitle else {
            selectedSubtitle = nil
            subtitleCues = []
            return
        }
        guard let model, let url = subtitle.url else { return }
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

    @discardableResult
    func sendDanmaku(_ text: String) async -> Bool {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let model, let resolved else { return false }
        let start = currentTime
        let sent = await model.sendDanmaku(
            cid: resolved.cid,
            bvid: resolved.bvid,
            progressMS: Int64(max(start, 0) * 1000),
            content: message
        )
        guard sent else { return false }
        danmakuItems.append(
            DanmakuItem(id: "local-\(UUID().uuidString)", start: start, mode: 1, text: message)
        )
        danmakuItems.sort { $0.start < $1.start }
        assignDanmakuLanes()
        return true
    }

    func cancelAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
        autoplayCountdown = nil
        nextVideo = nil
    }

    func attach(playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              playerLayer.player != nil else { return }
        if let existing = pipController, existing.playerLayer === playerLayer { return }
        pipController?.delegate = nil
        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else { return }
        controller.delegate = self
        pipController = controller
    }

    func togglePiP() {
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
    }

    func stop() {
        cancelAutoplay()
        if isReady, !didReachEnd {
            reportProgress(event: "pause", seconds: currentTime)
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        pipController?.delegate = nil
        pipController = nil
        teardownPlayer()
        monitorTask?.cancel()
        monitorTask = nil
        progressTask?.cancel()
        progressTask = nil
        if let sessionID, let model {
            self.sessionID = nil
            Task { await model.stopStream(sessionID: sessionID) }
        }
        self.video = nil
        self.model = nil
    }

    private func teardownPlayer() {
        statusTask?.cancel()
        statusTask = nil
        removeEndObserver()
        player?.pause()
        player = nil
        sessionID = nil
    }

    private func observeEnd(of item: AVPlayerItem) {
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handlePlaybackEnd() }
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func handlePlaybackEnd() {
        isPlaying = false
        didReachEnd = true
        currentTime = duration
        reportProgress(event: "end", seconds: duration)
        scheduleAutoplay()
    }

    private func scheduleAutoplay() {
        guard autoplayNext, let model, let video else { return }
        guard let next = model.relatedVideos.first(where: { $0.bvid != video.bvid }) else { return }
        nextVideo = next
        autoplayCountdown = 3
        autoplayTask?.cancel()
        autoplayTask = Task { @MainActor in
            while let remaining = autoplayCountdown, remaining > 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                autoplayCountdown = remaining - 1
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, didReachEnd, nextVideo?.bvid == next.bvid else { return }
            autoplayCountdown = nil
            nextVideo = nil
            onRequestPlayNext?(next)
        }
    }

    private func startMonitor() {
        guard monitorTask == nil else { return }
        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                updatePlaybackState()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
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

    private func startProgressLoop() {
        guard progressTask == nil else { return }
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled, isReady, isPlaying else { continue }
                reportProgress(event: "heartbeat", seconds: currentTime)
            }
        }
    }

    private func reportProgress(event: String, seconds: Double) {
        guard let model, let video, let resolved, isReady || event == "end" else { return }
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

    private func ensureDanmakuSegment(for seconds: Double) {
        guard danmakuEnabled,
              let model,
              let resolved,
              seconds.isFinite,
              seconds >= 0 else { return }
        let segment = Int(seconds / 360) + 1
        guard !loadedDanmakuSegments.contains(segment) else { return }
        loadedDanmakuSegments.insert(segment)
        let cid = resolved.cid
        Task {
            do {
                let items = try await model.fetchDanmaku(cid: cid, segment: segment)
                guard self.resolved?.cid == cid else { return }
                let existing = Set(danmakuItems.map(\.id))
                danmakuItems.append(contentsOf: items.filter { !existing.contains($0.id) })
                danmakuItems.sort { $0.start < $1.start }
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
        let order = danmakuItems.indices.sorted { danmakuItems[$0].start < danmakuItems[$1].start }
        let scrollLifetime = 8.0 / max(0.25, danmakuSpeed)
        for index in order {
            let item = danmakuItems[index]
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
                        danmakuItems[index].lane = -1
                        continue
                    }
                    chosen = earliestLane
                }
                danmakuItems[index].lane = chosen
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
                    danmakuItems[index].lane = -1
                    continue
                }
                danmakuItems[index].lane = chosen
                freeAt[chosen] = item.start + 4.0
                if isTop {
                    topFreeAt = freeAt
                } else {
                    bottomFreeAt = freeAt
                }
            }
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

    private func initialResume(from result: PlayerResolveResult) -> Double {
        let resume = result.resumeSeconds
        let total = Double(result.durationMS ?? 0) / 1000
        guard resume > 3 else { return 0 }
        guard total <= 0 || resume < total - 2 else { return 0 }
        return resume
    }

    private func playbackMessage(_ error: Error) -> String {
        if case let BBCoreError.rpc(_, message) = error, !message.isEmpty {
            return message
        }
        return "视频加载失败，请稍后重试"
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}

extension MobilePlaybackController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in isPiPActive = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in isPiPActive = false }
    }

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
    }
}
