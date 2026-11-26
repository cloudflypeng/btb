import SwiftUI

enum MobileSheetRoute: Hashable {
    case up(MobileUPRoute)
}

@MainActor
@Observable
final class MobileRouter {
    var selectedTab: MobileTab = .home
    var isPlayerPresented = false
    /// Bumped when the bottom tab that is already selected is tapped again
    /// (#3): the page jumps back to its top, as the YouTube tab does.
    var retapToken = 0
    /// The bottom bar is off-screen: the feed owns the whole screen while it
    /// scrolls down, exactly like the header.
    var tabBarHidden = false
    var rootVideo: VideoItem?
    var path: [MobileSheetRoute] = []

    func open(_ video: VideoItem) {
        // Opening the same video again takes over from its floating window.
        MobilePiPSession.end(forBVID: video.bvid, stopPlayback: true)
        rootVideo = video
        path = []
        isPlayerPresented = true
    }

    func play(_ video: VideoItem) {
        MobilePiPSession.end(forBVID: video.bvid, stopPlayback: true)
        rootVideo = video
        path = []
    }

    func pushUP(_ route: MobileUPRoute) {
        path.append(.up(route))
    }

    func dismiss() {
        isPlayerPresented = false
    }
}

struct MobileVideoLink<Label: View>: View {
    let video: VideoItem
    @ViewBuilder let label: () -> Label

    @Environment(MobileRouter.self) private var router
    @Environment(AppModel.self) private var model
    @Environment(\.playerTransitionNamespace) private var transitionNamespace

    var body: some View {
        if #available(iOS 18.0, *), let transitionNamespace {
            button.matchedTransitionSource(id: video.bvid, in: transitionNamespace)
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            if router.isPlayerPresented {
                router.play(video)
            } else {
                router.open(video)
            }
        } label: {
            label()
        }
        // B1: start resolve + stream on touch-down, so the player opens warm.
        .buttonStyle(BtbPressableStyle(onPressDown: { model.prefetchPlayback(video) }))
        // C3: long press shows a muted clip plus the quick actions.
        .videoContextMenu(video, model: model)
    }
}

/// Namespace for the card → player zoom transition (C1), injected at the root
/// so every card can be a transition source.
private struct PlayerTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var playerTransitionNamespace: Namespace.ID? {
        get { self[PlayerTransitionNamespaceKey.self] }
        set { self[PlayerTransitionNamespaceKey.self] = newValue }
    }
}

/// Zooms the player sheet out of the card that opened it (iOS 18+). On iOS 17
/// the sheet keeps its default slide, since there is no zoom presentation.
struct PlayerZoomTransition: ViewModifier {
    let bvid: String?
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let bvid {
            content.navigationTransition(.zoom(sourceID: bvid, in: namespace))
        } else {
            content
        }
    }
}
