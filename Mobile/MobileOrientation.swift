import SwiftUI
import UIKit

/// The app is portrait-only except while the player page is open, where it
/// rotates normally and the video takes the whole screen (#7). The delegate
/// below reads this mask; the player flips it on appear / disappear.
@MainActor
final class MobileOrientation {
    static let shared = MobileOrientation()

    private(set) var allowsLandscape = false

    var mask: UIInterfaceOrientationMask {
        allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }

    func setAllowsLandscape(_ allowed: Bool) {
        guard allowed != allowsLandscape else { return }
        allowsLandscape = allowed
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
}

/// Fullscreen host still used by the anime player; the video page rotates the
/// app itself instead.
final class LandscapePlayerHost: UIHostingController<AnyView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

final class MobileAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { MobileOrientation.shared.mask }
    }
}

/// Window safe-area metrics.
///
/// SwiftUI reports zero safe-area insets inside a view that has already
/// `ignoresSafeArea` applied, so a page that wants a full-bleed top (content
/// sliding away under the status bar) has to read the real inset here instead.
@MainActor
enum MobileSafeArea {
    private static var insets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? scenes.first?.keyWindow
        return window?.safeAreaInsets ?? .zero
    }

    static var top: CGFloat { insets.top }

    /// The notch side while the phone is sideways; 0 in portrait.
    static var leading: CGFloat { insets.left }
    static var trailing: CGFloat { insets.right }
}
