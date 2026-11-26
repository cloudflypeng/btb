import AVKit
import AppKit
import SwiftUI

/// Mac floating mini-player (B6).
///
/// Puts the current video in an always-on-top panel so it stays watchable over
/// other apps and spaces without a full window. The panel shares the page's
/// `AVPlayer`, and it lives only as long as the player page does — closing the
/// video closes the window with it.
@MainActor
@Observable
final class FloatingPlayerWindow: NSObject, NSWindowDelegate {
    static let shared = FloatingPlayerWindow()

    private(set) var bvid: String?
    private(set) var isShowing = false

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var isClosing = false

    func toggle(player: AVPlayer, video: VideoItem) {
        if isShowing {
            close()
        } else {
            show(player: player, video: video)
        }
    }

    func show(player: AVPlayer, video: VideoItem) {
        let isNew = panel == nil
        let panel = panel ?? makePanel()
        self.panel = panel
        bvid = video.bvid
        panel.title = video.title
        panel.contentView = NSHostingView(rootView: FloatingPlayerContent(player: player))
        if isNew {
            panel.setContentSize(NSSize(width: 480, height: 270))
            if !panel.setFrameUsingName("BTBFloatingPlayer") {
                placeBottomTrailing(panel)
            }
            panel.setFrameAutosaveName("BTBFloatingPlayer")
        }
        panel.orderFront(nil)
        isShowing = true
    }

    func close() {
        guard let panel else { return }
        isClosing = true
        panel.contentView = nil
        panel.orderOut(nil)
        panel.close()
        isClosing = false
        bvid = nil
        isShowing = false
    }

    /// Closes the window if it is showing `bvid` — the player page it belongs to is going away.
    func closeOwned(by bvid: String) {
        guard self.bvid == bvid else { return }
        close()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .black
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 200)
        panel.delegate = self
        return panel
    }

    private func placeBottomTrailing(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(
                x: visible.maxX - size.width - 24,
                y: visible.minY + 24
            )
        )
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard !isClosing else { return }
            bvid = nil
            isShowing = false
            panel?.contentView = nil
        }
    }
}

private struct FloatingPlayerContent: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = false
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player = nil
    }
}
