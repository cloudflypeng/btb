import Foundation

/// Short-lived hand-off cache for the playback pipeline.
///
/// A finger going down on a video card starts `player.resolve` (and, once the
/// quality is known, `stream.start`) so the player page can hand AVPlayer a URL
/// without waiting on the network. Entries are keyed so a later tap on a
/// different card simply misses, and the whole cache is capped and aged out —
/// a fast scroll must never pile up gateway sessions.
@MainActor
final class PlaybackPrewarmCache {
    struct StreamEntry {
        let key: String
        let session: StreamSession
        let createdAt: Date
    }

    /// `player.resolve` embeds a playurl call, so it stays warm only briefly.
    static let resolveTTL: TimeInterval = 60
    /// A started stream holds CDN URLs and an in-memory gateway session.
    static let streamTTL: TimeInterval = 60
    static let maxStreams = 3

    private var resolved: [String: (result: PlayerResolveResult, at: Date)] = [:]
    private var streams: [StreamEntry] = []
    private var inFlight: Set<String> = []
    /// Stream keys a prefetch is currently preparing.
    private var pendingStreams: Set<String> = []
    /// Callers waiting on an in-flight stream; resumed with failure on timeout.
    private var streamWaiters: [String: [CheckedContinuation<StreamSession?, Never>]] = [:]
    /// Callers waiting on an in-flight resolve.
    private var resolveWaiters: [String: [CheckedContinuation<PlayerResolveResult?, Never>]] = [:]
    private var resolveStartedAt: [String: Date] = [:]
    private var streamPrepStartedAt: [String: Date] = [:]

    /// Called when a cached stream session is dropped without being played.
    var onEvictStream: ((String) -> Void)?

    static func resolveKey(bvid: String, page: Int, qn: Int64, codec: String) -> String {
        "\(bvid)|\(page)|\(qn)|\(codec)"
    }

    static func streamKey(bvid: String, cid: Int64?, qn: Int64, codec: String) -> String {
        "\(bvid)|\(cid ?? 0)|\(qn)|\(codec)"
    }

    // MARK: resolve

    func isResolving(_ key: String) -> Bool {
        inFlight.contains(key)
    }

    func beginResolve(_ key: String, now: Date = Date()) {
        inFlight.insert(key)
        resolveStartedAt[key] = now
    }

    func endResolve(_ key: String) {
        inFlight.remove(key)
        resolveStartedAt[key] = nil
    }

    func storeResolved(_ result: PlayerResolveResult, for key: String, now: Date = Date()) {
        prune(now)
        resolved[key] = (result, now)
    }

    /// Completes an in-flight resolve: caches it and wakes anyone waiting on it
    /// (a quick tap that lands mid-prefetch).
    func finishResolve(_ key: String, _ result: PlayerResolveResult?) {
        inFlight.remove(key)
        resolveStartedAt[key] = nil
        if let result {
            resolved[key] = (result, Date())
        }
        let waiters = resolveWaiters.removeValue(forKey: key) ?? []
        for waiter in waiters {
            waiter.resume(returning: result)
        }
    }

    func takeResolved(for key: String, now: Date = Date()) -> PlayerResolveResult? {
        prune(now)
        guard let entry = resolved.removeValue(forKey: key) else { return nil }
        return entry.result
    }

    /// Cached resolve, or a join onto the resolve a press already started.
    ///
    /// A prep that has already run longer than `budget` is not worth waiting
    /// for — a fresh request would finish sooner.
    func awaitResolved(for key: String, budget: Duration, now: Date = Date()) async -> PlayerResolveResult? {
        if let warm = takeResolved(for: key, now: now) {
            return warm
        }
        guard inFlight.contains(key) else { return nil }
        let elapsed = now.timeIntervalSince(resolveStartedAt[key] ?? now)
        let remaining = Self.seconds(budget) - elapsed
        guard remaining > 0.05 else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<PlayerResolveResult?, Never>) in
            resolveWaiters[key, default: []].append(continuation)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                guard let waiters = self.resolveWaiters.removeValue(forKey: key) else { return }
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
        }
    }

    // MARK: stream

    func storeStream(_ session: StreamSession, for key: String, now: Date = Date()) {
        prune(now)
        streams.removeAll { $0.key == key }
        streams.append(StreamEntry(key: key, session: session, createdAt: now))
        while streams.count > Self.maxStreams {
            let evicted = streams.removeFirst()
            onEvictStream?(evicted.session.sessionID)
        }
    }

    func takeStream(for key: String, now: Date = Date()) -> StreamSession? {
        prune(now)
        guard let index = streams.firstIndex(where: { $0.key == key }) else { return nil }
        return streams.remove(at: index).session
    }

    // MARK: joinable prep

    func beginStreamPrep(_ key: String, now: Date = Date()) {
        pendingStreams.insert(key)
        streamPrepStartedAt[key] = now
    }

    /// Resolves a pending prep. Returns true when a waiting player took the
    /// session, in which case it must not also be cached.
    @discardableResult
    func finishStreamPrep(_ key: String, _ session: StreamSession?) -> Bool {
        pendingStreams.remove(key)
        streamPrepStartedAt[key] = nil
        guard let waiters = streamWaiters.removeValue(forKey: key), !waiters.isEmpty else { return false }
        for waiter in waiters {
            waiter.resume(returning: session)
        }
        return session != nil
    }

    /// A cached stream, or the result of a prep already running for this exact
    /// rendition — waiting briefly beats starting a second identical session.
    func awaitStream(for key: String, budget: Duration, now: Date = Date()) async -> StreamSession? {
        if let warm = takeStream(for: key, now: now) {
            return warm
        }
        guard pendingStreams.contains(key) else { return nil }
        let elapsed = now.timeIntervalSince(streamPrepStartedAt[key] ?? now)
        let remaining = Self.seconds(budget) - elapsed
        guard remaining > 0.05 else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<StreamSession?, Never>) in
            streamWaiters[key, default: []].append(continuation)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                guard let waiters = self.streamWaiters.removeValue(forKey: key) else { return }
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
        }
    }

    /// Drops every cached session without touching the resolve cache.
    func dropStreams(now: Date = Date()) {
        for entry in streams {
            onEvictStream?(entry.session.sessionID)
        }
        streams.removeAll()
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }

    // MARK: housekeeping

    private func prune(_ now: Date) {
        resolved = resolved.filter { now.timeIntervalSince($0.value.at) < Self.resolveTTL }
        var survivors: [StreamEntry] = []
        for entry in streams {
            if now.timeIntervalSince(entry.createdAt) < Self.streamTTL {
                survivors.append(entry)
            } else {
                onEvictStream?(entry.session.sessionID)
            }
        }
        streams = survivors
    }
}
