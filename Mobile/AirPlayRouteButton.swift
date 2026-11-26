import AVKit
import SwiftUI

/// The system AirPlay route picker, drawn as an invisible layer under our own
/// icon. Apple's picker view is the only supported way to bring up the route
/// list, and it cannot be opened programmatically — so it has to be the thing
/// the finger actually lands on.
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        // Transparent: the glyph below this view is ours, so it matches the
        // rest of the action row.
        view.tintColor = .clear
        view.activeTintColor = .clear
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = .clear
        uiView.activeTintColor = .clear
    }
}
