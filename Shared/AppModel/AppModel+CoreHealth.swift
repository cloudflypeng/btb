#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

/// Keeps bbcore alive for the whole session.
///
/// The core is the only thing that talks to Bilibili: covers, feeds, danmaku,
/// the HLS gateway that feeds AVPlayer and downloads all go through it. When
/// it stops answering, nothing in the app can recover on its own, so a
/// watchdog pings it every few seconds and restarts it in place. A playback
/// that failed to load asks for the same restart, then tries once more.
extension AppModel {
    /// How long a ping may take before the core counts as gone, and how long
    /// the first ping after a restart may take (the Go service reopens its
    /// state and its gateway).
    private static let corePingTimeout: Double = 5
    private static let coreRecoveryPingTimeout: Double = 12

    var isRecoveringCore: Bool { coreRecoveryTask != nil }

    /// Pings the core once. `false` means it stopped answering.
    func pingCore() async -> Bool {
        guard coreState == .ready else { return false }
        do {
            let core = self.core
            _ = try await Self.withCoreTimeout(Self.corePingTimeout) {
                try await core.call("core.ping")
            }
            return true
        } catch {
            return false
        }
    }

    /// Restarts bbcore. Concurrent callers share the one restart in flight.
    /// Returns whether the core answers again afterwards.
    @discardableResult
    func recoverCore(reason: String) async -> Bool {
        if let task = coreRecoveryTask {
            return await task.value
        }
        // A restart that just happened is enough: streaming surfaces call
        // this when their item fails, but the core itself may already be
        // healthy again.
        if let last = lastCoreRecoveryAt, Date().timeIntervalSince(last) < 20,
           await pingCore() {
            return true
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return false }
            return await self.runCoreRecovery(reason: reason)
        }
        coreRecoveryTask = task
        let recovered = await task.value
        coreRecoveryTask = nil
        return recovered
    }

    private func runCoreRecovery(reason: String) async -> Bool {
        guard started else { return false }
#if DEBUG
        btbDebugLog("core: recovering (\(reason))")
#endif
        Perf.milestone("core.recover", "reason=\(reason)")
        coreRecoveryCount += 1
        lastCoreRecoveryAt = Date()

        // Every transport tears down cleanly and comes back up from `start`:
        // the embedded one reloads the Go service in place, the HTTP one
        // reconnects, and the macOS child process is respawned.
        await core.stop()
        do {
            try await core.start()
        } catch {
            coreState = .failed("核心服务重启失败：\(describe(error))")
            return false
        }

        // The event stream object survives a restart; make sure its consumer
        // is running in case the transport ended it on the way down.
        eventHub.start()

        do {
            let core = self.core
            _ = try await Self.withCoreTimeout(Self.coreRecoveryPingTimeout) {
                try await core.call("core.ping")
            }
        } catch {
            coreState = .failed("核心服务未能恢复：\(describe(error))")
            return false
        }

        await eventHub.refreshCapabilities()
        coreState = .ready
        // Gateway ports and download settings are per-core; put them back.
        await applyDownloadConfig()
        if downloadLoaded {
            await loadDownloads(force: true)
        }
        showToast("核心服务已重新连接")
        // Streams handed out before the restart point at the old gateway;
        // the surfaces on screen use this to ask for fresh URLs.
        NotificationCenter.default.post(name: .btbCoreRecovered, object: nil)
#if DEBUG
        btbDebugLog("core: recovered")
#endif
        return true
    }

    /// Starts the background health check. Idempotent.
    func startCoreWatchdog() {
        guard coreWatchdogTask == nil else { return }
#if canImport(UIKit)
        // Coming back from the background is the moment a long-suspended
        // session is most likely to have lost its streams; check right away
        // instead of waiting for the next tick.
        coreForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.coreState == .ready, !self.isRecoveringCore else { return }
                if !(await self.pingCore()) {
                    await self.recoverCore(reason: "foreground")
                }
            }
        }
#endif
        coreWatchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.coreState == .ready, !self.isRecoveringCore else { continue }
                // iOS suspends the whole process in the background; a ping
                // there would say nothing about the core's health.
#if canImport(UIKit)
                guard UIApplication.shared.applicationState == .active else { continue }
#endif
                if !(await self.pingCore()) {
                    await self.recoverCore(reason: "watchdog")
                }
            }
        }
    }

    func stopCoreWatchdog() {
        coreWatchdogTask?.cancel()
        coreWatchdogTask = nil
        if let coreForegroundObserver {
            NotificationCenter.default.removeObserver(coreForegroundObserver)
            self.coreForegroundObserver = nil
        }
    }

    /// Races one core call against a deadline. A call that already reached
    /// the Go service cannot be cancelled, but one that never gets an answer
    /// still lets the caller move on to a restart.
    private static func withCoreTimeout<T: Sendable>(
        _ seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw BBCoreError.connection("核心响应超时")
            }
            guard let value = try await group.next() else {
                throw BBCoreError.connection("核心响应超时")
            }
            group.cancelAll()
            return value
        }
    }
}

extension Notification.Name {
    /// Posted after bbcore was restarted: every stream URL handed out by the
    /// old instance is dead.
    static let btbCoreRecovered = Notification.Name("com.cloudflypeng.btb.coreRecovered")
}
