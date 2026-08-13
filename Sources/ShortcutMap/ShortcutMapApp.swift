import SwiftUI

@main
struct ShortcutMapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.model)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear { appDelegate.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)

        Settings {
            SettingsView()
        }
    }
}
