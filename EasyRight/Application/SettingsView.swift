import SwiftUI
import EasyRightCore

struct SettingsView: View {
    let actionRegistry: ActionRegistry

    var body: some View {
        Form {
            Section("Actions") {
                ForEach(actionRegistry.actions) { action in
                    Toggle(isOn: .constant(true)) {
                        Label(action.title, systemImage: action.systemImageName)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .padding(18)
    }
}
