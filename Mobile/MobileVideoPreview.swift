import AVFoundation
import SwiftUI

/// Muted auto-playing clip for the long-press card preview (C3).
///
/// Reuses the press-down prewarm, so a long press on a card the finger is
/// already on usually has both the resolve and the stream waiting. The clip
/// plays silently and stops as soon as the preview goes away; every failure
/// just leaves the cover in place.
@MainActor
@Observable
final class PreviewPlayback {
    private(set) var player: AVPlayer?
    private(set) var isReady = false

    @ObservationIgnored private var sessionID: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    func start(video: VideoItem, model: AppModel) {
        guard player == nil, task == nil else { return }
        let qn = model.playbackCeilingQN
        let codec = model.playbackPreferredCodec
        task = Task { @MainActor [weak self] in
            defer { self?.task = nil }
            guard let self else { return }
            do {
                let result: PlayerResolveResult
                if let warm = await model.prewarmedResolve(for: video, budget: .milliseconds(250)) {
                    result = warm
                } else {
                    result = try await model.resolvePlayback(
                        for: video,
                        page: 1,
                        qn: qn,
                        codec: codec,
                        cid: video.cid.map(Int64.init)
                    )
                }
                guard !Task.isCancelled, result.canPlay,
                      let quality = result.preferredQuality(defaultQN: qn, defaultCodec: codec)
                else { return }
                let stream: StreamSession
                if let warm = await model.prewarmedStream(
                    bvid: result.bvid,
                    cid: result.cid,
                    qn: quality.qn,
                    codec: quality.codec ?? codec
                ) {
                    stream = warm
                } else {
                    stream = try await model.startStream(
                        bvid: result.bvid,
                        cid: result.cid,
                        qn: quality.qn,
                        codec: quality.codec ?? "hevc"
                    )
                }
                guard !Task.isCancelled, let url = stream.playbackURL else {
                    await model.stopStream(sessionID: stream.sessionID)
                    return
                }
                sessionID = stream.sessionID
                let item = AVPlayerItem(url: url)
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                player.actionAtItemEnd = .pause
                self.player = player
                statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
                    guard observed.status == .readyToPlay else { return }
                    Task { @MainActor [weak self] in
                        guard let self, self.player === player else { return }
                        self.isReady = true
                        player.play()
                    }
                }
            } catch {
                #if DEBUG
                btbDebugLog("preview: failed \(error)")
                #endif
            }
        }
    }

    func stop(model: AppModel) {
        task?.cancel()
        task = nil
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        isReady = false
        guard let sessionID else { return }
        self.sessionID = nil
        Task { await model.stopStream(sessionID: sessionID) }
    }
}

/// The long-press preview: cover first, then the muted clip fading in over it.
struct MobileVideoPreview: View {
    let video: VideoItem

    @Environment(AppModel.self) private var model
    @State private var playback = PreviewPlayback()

    var body: some View {
        ZStack {
            RemoteImage(url: video.coverURL)
                .frame(width: 320, height: 180)
                .clipped()

            if let player = playback.player {
                VideoSurface(player: player, playback: nil)
                    .opacity(playback.isReady ? 1 : 0)
                    .animation(BtbMotion.smooth, value: playback.isReady)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.35), radius: 8)
            }

            if !playback.isReady {
                VStack {
                    Spacer()
                    HStack {
                        Text(video.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(.black.opacity(0.55))
                }
            }
        }
        .task {
            // A brief beat so flicking past cards does not start streams.
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            playback.start(video: video, model: model)
        }
        .onDisappear {
            playback.stop(model: model)
        }
    }
}

extension View {
    /// Long-press menu with a muted autoplaying preview (C3).
    func videoContextMenu(_ video: VideoItem, model: AppModel) -> some View {
        contextMenu {
            Button {
                Task { await model.addToWatchLater(video) }
            } label: {
                Label("稍后再看", systemImage: "clock")
            }
            ShareLink(item: video.pageURL) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            Button {
                Task { await model.startDownload(for: video, detail: nil) }
            } label: {
                Label("缓存到本地", systemImage: "arrow.down.circle")
            }
        } preview: {
            MobileVideoPreview(video: video)
                .environment(model)
        }
    }
}
