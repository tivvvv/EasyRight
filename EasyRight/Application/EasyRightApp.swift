import SwiftUI

import EasyRightCore

@main
struct EasyRightApp: App {
    private let actionRegistry = ActionRegistry.standard

    var body: some Scene {
        WindowGroup {
            RootView(actionRegistry: actionRegistry)
        }

        Settings {
            SettingsView(actionRegistry: actionRegistry)
        }
    }
}
