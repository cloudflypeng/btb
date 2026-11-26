import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Keeps playback running in a system PiP window after the player page closes (B6).
///
/// `AVPictureInPictureController(playerLayer:)` is tied to its layer: the moment
/// that layer leaves the window, PiP stops. The page's own surface therefore
/// cannot carry PiP through the sheet dismissal. This session instead parks a
/// full-window `AVPlayerLayer` of the same `AVPlayer` at the bottom of the window
/// — behind the opaque root view, so it never shows, but it is on screen and
/// rendering — and hands PiP that layer. It also owns the playback controller,
/// which would otherwise be released along with the page.
@MainActor
final class MobilePiPSession: NSObject {
    private static var active: MobilePiPSession?

    /// Set by `MobileRootView` to reopen the player page from the PiP expand button.
    static var onRestore: ((VideoItem) -> Void)?

    private let playback: MobilePlaybackController
    private let video: VideoItem
    private let container = PiPHostView()
    private var layer: AVPlayerLayer { container.videoLayer }
    private var controller: AVPictureInPictureController?
    private var didRestore = false
    private var startTask: Task<Void, Never>?

    private init(playback: MobilePlaybackController, video: VideoItem) {
        self.playback = playback
        self.video = video
        super.init()
    }

    /// Hands `playback` to a floating window. Returns `false` when there is
    /// nothing worth keeping alive (paused, finished, unsupported, no window) —
    /// the caller must then stop the playback itself.
    @discardableResult
    static func start(playback: MobilePlaybackController, video: VideoItem) -> Bool {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              playback.isReady,
              !playback.didReachEnd,
              playback.isPlaying,
              playback.player != nil
        else {
            pipLog("skip supported=\(AVPictureInPictureController.isPictureInPictureSupported()) ready=\(playback.isReady) playing=\(playback.isPlaying) ended=\(playback.didReachEnd)")
            return false
        }
        if let current = active {
            if current.video.bvid == video.bvid { return true }
            current.finish(stopPlayback: true)
        }
        guard let window = keyWindow() else { return false }
        let session = MobilePiPSession(playback: playback, video: video)
        guard session.begin(in: window) else { return false }
        active = session
        return true
    }

    /// Closes a floating window that belongs to `bvid`, used when the video ends
    /// or the same video is opened again in the app.
    static func end(forBVID bvid: String, stopPlayback: Bool) {
        guard let current = active, current.video.bvid == bvid else { return }
        current.finish(stopPlayback: stopPlayback)
    }

    static func endAll(stopPlayback: Bool) {
        active?.finish(stopPlayback: stopPlayback)
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow ?? scene?.windows.first(where: \.isKeyWindow)
    }

    private func begin(in window: UIWindow) -> Bool {
        guard let player = playback.player else { return false }
        container.frame = window.bounds
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.isUserInteractionEnabled = false
        container.accessibilityElementsHidden = true
        layer.videoGravity = .resizeAspect
        layer.player = player
        window.insertSubview(container, at: 0)

        guard let pip = AVPictureInPictureController(playerLayer: layer) else {
            teardownContainer()
            return false
        }
        pip.delegate = self
        pip.canStartPictureInPictureAutomaticallyFromInline = false
        controller = pip
        // The layer needs a moment in the hierarchy before AVKit considers it
        // eligible; retry briefly instead of giving up on the first frame.
        startTask = Task { @MainActor [weak self] in
            for attempt in 0..<16 {
                guard let self, let pip = self.controller else { return }
                if pip.isPictureInPicturePossible {
                    pipLog("start bvid=\(self.video.bvid) attempt=\(attempt)")
                    pip.startPictureInPicture()
                    return
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
            }
            guard let self else { return }
            pipLog("never possible bvid=\(self.video.bvid)")
            finish(stopPlayback: true)
        }
        return true
    }

    private func finish(stopPlayback: Bool) {
        startTask?.cancel()
        startTask = nil
        let pip = controller
        controller = nil
        pip?.delegate = nil
        if pip?.isPictureInPictureActive == true {
            pip?.stopPictureInPicture()
        }
        teardownContainer()
        if MobilePiPSession.active === self {
            MobilePiPSession.active = nil
        }
        if stopPlayback {
            playback.stop()
        }
    }

    private func teardownContainer() {
        layer.player = nil
        container.removeFromSuperview()
    }
}

/// Hidden host for the detached player layer. It sits at the bottom of the
/// window, so it renders behind the app's opaque root view.
private final class PiPHostView: UIView {
    let videoLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        videoLayer.videoGravity = .resizeAspect
        layer.addSublayer(videoLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        CATransaction.commit()
    }
}

extension MobilePiPSession: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            playback.setPiPActive(true)
            pipLog("started bvid=\(video.bvid)")
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            playback.setPiPActive(false)
            pipLog("stopped bvid=\(video.bvid) restored=\(didRestore)")
            if !didRestore, MobilePiPSession.active === self {
                finish(stopPlayback: true)
            }
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            pipLog("failed \(error.localizedDescription)")
            self?.finish(stopPlayback: true)
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler(false)
                return
            }
            didRestore = true
            let video = video
            let playback = playback
            // Record the position for the page we are about to open, then hand
            // the video back so it resumes where the floating window left off.
            finish(stopPlayback: false)
            playback.setPiPActive(false)
            playback.stop()
            let reopen = MobilePiPSession.onRestore
            pipLog("restore bvid=\(video.bvid) reopen=\(reopen != nil)")
            reopen?(video)
            completionHandler(reopen != nil)
        }
    }
}

#if DEBUG
@inline(__always)
private func pipLog(_ message: @autoclosure () -> String) {
    let line = "pip: \(message())"
    print(line)
    fflush(stdout)
    NSLog("%@", line)
}
#else
@inline(__always)
private func pipLog(_ message: @autoclosure () -> String) {}
#endif
