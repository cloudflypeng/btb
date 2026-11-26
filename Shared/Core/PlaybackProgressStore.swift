import Foundation
import Observation

/// One locally remembered playback position.
struct PlaybackMark: Codable, Hashable {
    var seconds: Double
    var duration: Double
    /// CID the position belongs to, so a multi-part video never resumes an
    /// unrelated part.
    var cid: Int64?
    var updatedAt: Date

    /// 0…1, or 0 when the duration is still unknown.
    var fraction: Double {
        guard duration > 0.5 else { return 0 }
        return min(max(seconds / duration, 0), 1)
    }

    /// Positions within the first few seconds or the closing seconds are not
    /// worth resuming from.
    var isResumable: Bool {
        guard seconds > 3 else { return false }
        guard duration > 0.5 else { return true }
        return seconds < duration - 2
    }
}

/// Local, per-video playback positions (plan item B4).
///
/// Written on every progress report the player already sends upstream, so the
/// number matches what Bilibili has, but is available instantly and offline.
/// Merged with the cloud history when a video opens: whichever is further wins.
@MainActor
@Observable
final class PlaybackProgressStore {
    static let shared = PlaybackProgressStore()

    private struct FileShape: Codable {
        var marks: [String: PlaybackMark]
    }

    private static let maxEntries = 600

    private(set) var marks: [String: PlaybackMark]
    @ObservationIgnored private var pendingFlush: Task<Void, Never>?
    @ObservationIgnored private var needsFlush = false

    private init() {
        marks = Self.read()
    }

    private static var file: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("btb-playback-progress.json")
    }

    func mark(for bvid: String) -> PlaybackMark? {
        marks[bvid]
    }

    /// Position to show on a cover: only meaningful once the video was opened.
    func fraction(for bvid: String) -> Double {
        guard let mark = marks[bvid], mark.seconds > 1 else { return 0 }
        guard mark.duration > 0.5 else { return 0 }
        let value = mark.fraction
        // A finished video shows a full bar; a barely-started one shows nothing.
        return value < 0.02 ? 0 : value
    }

    /// Resume position for a video opened at a specific part.
    func resumeSeconds(for bvid: String, cid: Int64?) -> Double {
        guard let mark = marks[bvid] else { return 0 }
        if let cid, let storedCID = mark.cid, storedCID != cid {
            return 0
        }
        return mark.isResumable ? mark.seconds : 0
    }

    func record(bvid: String, cid: Int64?, seconds: Double, duration: Double) {
        guard !bvid.isEmpty, seconds.isFinite, seconds >= 0 else { return }
        let total = duration.isFinite && duration > 0 ? duration : 0
        var mark = marks[bvid] ?? PlaybackMark(seconds: 0, duration: total, cid: cid, updatedAt: Date())
        mark.seconds = seconds
        if total > 0 {
            mark.duration = total
        }
        if let cid {
            mark.cid = cid
        }
        mark.updatedAt = Date()
        // Finished videos restart from the top next time.
        if mark.duration > 1, mark.seconds >= mark.duration - 2 {
            mark.seconds = 0
        }
        marks[bvid] = mark
        trimIfNeeded()
        scheduleFlush()
    }

    func clear() {
        marks.removeAll()
        needsFlush = true
        flush()
    }

    func flush() {
        pendingFlush?.cancel()
        pendingFlush = nil
        guard needsFlush else { return }
        needsFlush = false
        let snapshot = marks
        let url = Self.file
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(FileShape(marks: snapshot)) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: private

    private func scheduleFlush() {
        needsFlush = true
        guard pendingFlush == nil else { return }
        pendingFlush = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    private func trimIfNeeded() {
        guard marks.count > Self.maxEntries else { return }
        let ordered = marks.sorted { $0.value.updatedAt > $1.value.updatedAt }
        marks = Dictionary(uniqueKeysWithValues: ordered.prefix(Self.maxEntries).map { ($0.key, $0.value) })
    }

    private static func read() -> [String: PlaybackMark] {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode(FileShape.self, from: data) else {
            return [:]
        }
        return decoded.marks
    }
}
