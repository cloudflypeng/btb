import Foundation

extension AppModel {
    /// Quality ceiling for prewarming. Read at press time so a setting change
    /// takes effect without restarting the app.
    var playbackCeilingQN: Int64 {
        let stored = UserDefaults.standard.integer(forKey: "player.defaultQN")
        return Int64(stored > 0 ? stored : 80)
    }

    var playbackPreferredCodec: String {
        let codec = UserDefaults.standard.string(forKey: "player.defaultCodec") ?? "hevc"
        return codec.isEmpty ? "hevc" : codec
    }

    /// Starts `player.resolve` and an HLS session for a card the user is
    /// pressing, so tapping it opens the player without a round trip (B1).
    /// Best effort: every failure is simply retried by the player on open.
    func prefetchPlayback(_ video: VideoItem) {
        guard coreState == .ready else { return }
        guard video.bvid != detailBVID else { return }

        let page = 1
        let qn = playbackCeilingQN
        let codec = playbackPreferredCodec
        let resolveKey = PlaybackPrewarmCache.resolveKey(bvid: video.bvid, page: page, qn: qn, codec: codec)
        guard !playbackPrewarm.isResolving(resolveKey) else { return }

        playbackPrewarmTask?.cancel()
        playbackPrewarm.beginResolve(resolveKey)
        let started = Date()
        playbackPrewarmTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let result: PlayerResolveResult
            do {
                result = try await self.resolvePlayback(for: video, page: page, qn: qn, codec: codec)
            } catch {
                self.playbackPrewarm.finishResolve(resolveKey, nil)
                Perf.milestone("prewarm.resolve", "failed=\(Self.prewarmErrorName(error))")
                return
            }
            let resolveMS = Int(Date().timeIntervalSince(started) * 1000)
            // Caches the result and wakes a tap that landed mid-flight.
            self.playbackPrewarm.finishResolve(resolveKey, result)

            guard !Task.isCancelled else { return }
            guard result.canPlay,
                  let quality = result.preferredQuality(defaultQN: qn, defaultCodec: codec) else {
                Perf.milestone("prewarm.resolve", "unplayable \(resolveMS) ms")
                return
            }
            let streamKey = PlaybackPrewarmCache.streamKey(
                bvid: result.bvid,
                cid: result.cid,
                qn: quality.qn,
                codec: quality.codec ?? codec
            )
            self.playbackPrewarm.beginStreamPrep(streamKey)
            do {
                let stream = try await self.startStream(
                    bvid: result.bvid,
                    cid: result.cid,
                    qn: quality.qn,
                    codec: quality.codec ?? "hevc"
                )
                guard !Task.isCancelled else {
                    self.playbackPrewarm.finishStreamPrep(streamKey, nil)
                    await self.stopStream(sessionID: stream.sessionID)
                    return
                }
                // A waiting player owns the session; caching it too would let
                // the eviction path stop a stream that is on screen.
                let claimed = self.playbackPrewarm.finishStreamPrep(streamKey, stream)
                if !claimed {
                    self.playbackPrewarm.storeStream(stream, for: streamKey)
                }
                let totalMS = Int(Date().timeIntervalSince(started) * 1000)
                Perf.milestone(
                    "prewarm.ready",
                    "resolve=\(resolveMS) ms total=\(totalMS) ms qn=\(quality.qn) joined=\(claimed)"
                )
            } catch {
                self.playbackPrewarm.finishStreamPrep(streamKey, nil)
                Perf.milestone("prewarm.stream", "failed resolve=\(resolveMS) ms")
            }
        }
    }

    /// The resolve for this video: warm from the press-down prefetch, or
    /// joined from one that is still in flight.
    func prewarmedResolve(
        for video: VideoItem,
        page: Int = 1,
        budget: Duration = .milliseconds(350)
    ) async -> PlayerResolveResult? {
        let key = PlaybackPrewarmCache.resolveKey(
            bvid: video.bvid,
            page: page,
            qn: playbackCeilingQN,
            codec: playbackPreferredCodec
        )
        return await playbackPrewarm.awaitResolved(for: key, budget: budget)
    }

    /// An HLS session for this exact rendition: warm from the cache, or joined
    /// from a prep that is already running (waiting up to `timeout`).
    func prewarmedStream(
        bvid: String,
        cid: Int64,
        qn: Int64,
        codec: String,
        budget: Duration = .milliseconds(450)
    ) async -> StreamSession? {
        let key = PlaybackPrewarmCache.streamKey(bvid: bvid, cid: cid, qn: qn, codec: codec)
        return await playbackPrewarm.awaitStream(for: key, budget: budget)
    }

    /// Drops anything still warm — called when the player closes.
    func discardPlaybackPrewarm() {
        playbackPrewarmTask?.cancel()
        playbackPrewarmTask = nil
        playbackPrewarm.dropStreams()
    }

    private static func prewarmErrorName(_ error: Error) -> String {
        if case let BBCoreError.rpc(code, _) = error { return "rpc\(code)" }
        if case let BBCoreError.upstream(code, _) = error { return "upstream\(code)" }
        return "\(error)"
    }
}
