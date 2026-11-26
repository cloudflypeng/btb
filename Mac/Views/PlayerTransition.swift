import SwiftUI

@MainActor
@Observable
final class PlayerTransitionController {
    var heroVideo: VideoItem?
    var heroFrame: CGRect = .zero
    var isHeroVisible = false
    var heroOpacity: Double = 1
    var backdropOpacity: Double = 0
    var isDetailVisible = false
    var detailOpacity: Double = 0
    var isSettled = false

    @ObservationIgnored private var sourceFrames: [String: CGRect] = [:]
    @ObservationIgnored private var openToken = UUID()

    private static let openAnimation = Animation.spring(response: 0.52, dampingFraction: 0.82)

    func registerSourceFrame(_ frame: CGRect, for id: String) {
        guard frame.width > 1, frame.height > 1 else { return }
        sourceFrames[id] = frame
    }

    func sourceFrame(for id: String) -> CGRect? {
        sourceFrames[id]
    }

    func beginOpen(video: VideoItem, from source: CGRect, to destination: CGRect) {
        let token = UUID()
        openToken = token
        heroVideo = video
        heroFrame = source
        isHeroVisible = true
        heroOpacity = 1
        backdropOpacity = 0
        isDetailVisible = true
        detailOpacity = 0
        isSettled = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard self.openToken == token else { return }

            withAnimation(Self.openAnimation) {
                self.heroFrame = destination
                self.backdropOpacity = 1
            }

            try? await Task.sleep(nanoseconds: 600_000_000)
            guard self.openToken == token else { return }

            self.backdropOpacity = 1
            self.detailOpacity = 1
            withAnimation(BtbMotion.snappy) {
                self.backdropOpacity = 0
                self.heroOpacity = 0
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            guard self.openToken == token else { return }

            self.isHeroVisible = false
            self.heroVideo = nil
            self.heroOpacity = 1
            self.isSettled = true
        }
    }

    func completeOpenImmediately() {
        openToken = UUID()
        isHeroVisible = false
        heroVideo = nil
        heroOpacity = 1
        backdropOpacity = 0
        detailOpacity = 1
        isDetailVisible = true
        isSettled = true
    }

    func reset() {
        openToken = UUID()
        isHeroVisible = false
        heroVideo = nil
        heroOpacity = 1
        backdropOpacity = 0
        detailOpacity = 0
        isDetailVisible = false
        isSettled = false
    }
}

struct HeroOverlayView: View {
    @Environment(PlayerTransitionController.self) private var transition
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            if transition.isHeroVisible, let video = transition.heroVideo {
                ZStack {
                    AppTheme.surface(scheme)

                    if let url = video.coverURL,
                       let cached = ImageCache.shared.image(for: url) {
                        Image(nsImage: cached)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RemoteImage(url: video.coverURL)
                    }
                }
                .frame(width: transition.heroFrame.width, height: transition.heroFrame.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                }
                .offset(x: transition.heroFrame.minX, y: transition.heroFrame.minY)
                .opacity(transition.heroOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
