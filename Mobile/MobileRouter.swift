import SwiftUI

enum MobileSheetRoute: Hashable {
    case up(MobileUPRoute)
}

@MainActor
@Observable
final class MobileRouter {
    var selectedTab: MobileTab = .home
    var isPlayerPresented = false
    var rootVideo: VideoItem?
    var path: [MobileSheetRoute] = []

    func open(_ video: VideoItem) {
        rootVideo = video
        path = []
        isPlayerPresented = true
    }

    func play(_ video: VideoItem) {
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

    var body: some View {
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
    }
}
