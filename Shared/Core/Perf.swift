import Foundation
import os

/// Performance instrumentation (plan item A1).
///
/// Every metric is emitted twice:
/// - as an `OSSignposter` interval, visible in Instruments → "Points of Interest"/os_signpost;
/// - as a `perf:` log line with milliseconds, which `make perf` collects from `log stream`.
///
/// Metrics:
/// - `launch.firstFeed`   process start → first home feed rendered (cached or network)
/// - `feed.load`          home feed request → items assigned
/// - `video.firstFrame`   video opened → AVPlayerItem ready to play
enum Perf {
    static let subsystem = "com.cloudflypeng.btb.perf"
    static let log = Logger(subsystem: subsystem, category: "metrics")
    static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)

    /// Approximate process start: first access happens in the App initializer.
    static let processStart = ContinuousClock.now

    private static let state = OSAllocatedUnfairLock(initialState: [String: ContinuousClock.Instant]())
    private static let reported = OSAllocatedUnfairLock(initialState: Set<String>())

    /// Starts (or restarts) a named timer.
    static func begin(_ name: String) {
        state.withLock { $0[name] = ContinuousClock.now }
        signposter.emitEvent("begin", "\(name, privacy: .public)")
    }

    /// Ends a named timer started with `begin`. No-op if it wasn't started.
    static func end(_ name: String, _ detail: String = "") {
        guard let start = state.withLock({ $0.removeValue(forKey: name) }) else { return }
        record(name, since: start, detail)
    }

    /// Records a one-shot milestone measured from process start (reported once per launch).
    static func milestone(_ name: String, _ detail: String = "") {
        let first = reported.withLock { $0.insert(name).inserted }
        guard first else { return }
        record(name, since: processStart, detail)
    }

    private static func record(_ name: String, since start: ContinuousClock.Instant, _ detail: String) {
        let elapsed = ContinuousClock.now - start
        let ms = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        signposter.emitEvent("metric", "\(name, privacy: .public) \(ms, format: .fixed(precision: 1)) ms")
        log.notice("perf: \(name, privacy: .public) \(ms, format: .fixed(precision: 1), privacy: .public) ms \(detail, privacy: .public)")
        #if DEBUG
        // `devicectl device process launch --console` only forwards stdout,
        // which is how metrics are read off a physical device. Unbuffered so a
        // kill never swallows the tail of a run.
        print("perf: \(name) \(String(format: "%.1f", ms)) ms \(detail)")
        fflush(stdout)
        #endif
    }
}

#if DEBUG
/// Debug-only line to stdout, flushed immediately for device log capture.
/// Also mirrored through `NSLog` so `simctl log stream` sees it on the simulator.
@inline(__always)
func btbDebugLog(_ message: @autoclosure () -> String) {
    let text = message()
    print(text)
    fflush(stdout)
    NSLog("%@", text)
}
#endif
