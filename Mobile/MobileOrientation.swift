import SwiftUI
import UIKit

/// The app itself never rotates: it stays portrait and hands landscape to the
/// fullscreen player host (#7). The delegate below reads this mask, and the
/// player flips it while its fullscreen host is up.
@MainActor
final class MobileOrientation {
    static let shared = MobileOrientation()

    private(set) var allowsLandscape = false

    var mask: UIInterfaceOrientationMask {
        allowsLandscape ? .landscape : .portrait
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
    static var top: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? scenes.first?.keyWindow
        return window?.safeAreaInsets.top ?? 0
    }
}
