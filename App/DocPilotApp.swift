import SwiftUI

@main
struct DocPilotApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
                .frame(
                    minWidth: 760,
                    minHeight: 520
                )
        }
    }
}
