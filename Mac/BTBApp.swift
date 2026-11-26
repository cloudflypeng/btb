import SwiftUI

@main
struct BTBApp: App {
    @State private var model = AppModel(transport: BBCoreClient())

    init() {
        _ = Perf.processStart
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.start()
                }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1320, height: 840)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("搜索") {
                    model.focusSearchToken += 1
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("刷新当前页面") {
                    Task { await model.retry() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
