import AVFoundation
import MediaPlayer
import UIKit

/// Lock screen, Control Center and Dynamic Island integration (B5).
///
/// Mirrors the player into `MPNowPlayingInfoCenter` and routes the system
/// transport controls back to the player. The Dynamic Island picks this up on
/// its own once the app keeps playing with an active `.playback` audio session.
@MainActor
final class PlaybackNowPlaying {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onSeek: ((Double) -> Void)?
    var onNext: (() -> Void)?
    var canPlayNext = false

    private var commands: [(MPRemoteCommand, Any)] = []
    private var artworkTask: Task<Void, Never>?
    private var artworkBVID: String?

    func activate() {
        guard commands.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()

        add(center.playCommand) { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        add(center.pauseCommand) { [weak self] _ in
            self?.onPause?()
            return .success
        }
        add(center.togglePlayPauseCommand) { [weak self] _ in
            self?.onTogglePlayPause?()
            return .success
        }
        add(center.changePlaybackPositionCommand) { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.onSeek?(event.positionTime)
            return .success
        }
        add(center.nextTrackCommand) { [weak self] _ in
            guard let self, self.canPlayNext else { return .noSuchContent }
            self.onNext?()
            return .success
        }
        center.previousTrackCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    private func add(_ command: MPRemoteCommand, handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        let token = command.addTarget(handler: handler)
        commands.append((command, token))
    }

    func update(
        title: String,
        artist: String,
        duration: Double,
        elapsed: Double,
        rate: Double,
        coverURL: URL?,
        bvid: String
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsed, 0),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork = artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        let isFirst = MPNowPlayingInfoCenter.default().nowPlayingInfo == nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #if DEBUG
        if isFirst {
            btbDebugLog("nowplaying: \"\(title)\" rate=\(rate) duration=\(Int(duration))s")
        }
        #endif
        loadArtworkIfNeeded(coverURL: coverURL, bvid: bvid)
    }

    func clear() {
        artworkTask?.cancel()
        artworkTask = nil
        artwork = nil
        artworkBVID = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        for (command, token) in commands {
            command.removeTarget(token)
        }
        commands.removeAll()
    }

    private var artwork: MPMediaItemArtwork?

    private func loadArtworkIfNeeded(coverURL: URL?, bvid: String) {
        guard artwork == nil, artworkBVID != bvid, let coverURL else { return }
        artworkBVID = bvid
        artworkTask?.cancel()
        artworkTask = Task { @MainActor [weak self] in
            guard let image = await PlaybackNowPlaying.downloadCover(coverURL) else { return }
            guard !Task.isCancelled else { return }
            self?.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                info[MPMediaItemPropertyArtwork] = self?.artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private static func downloadCover(_ url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return UIImage(data: data)
    }
}
