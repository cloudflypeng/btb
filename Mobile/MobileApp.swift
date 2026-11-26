import SwiftUI

@main
struct BTBMobileApp: App {
    @State private var model = AppModel(transport: MobileCoreTransportFactory.make())

    init() {
        _ = Perf.processStart
    }

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environment(model)
                .task {
                    await model.start()
                }
        }
    }
}
