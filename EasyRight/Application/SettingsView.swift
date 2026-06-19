import SwiftUI

import EasyRightCore

struct SettingsView: View {
    let actionRegistry: ActionRegistry

    @State private var enabledActionIDs: Set<ActionIdentifier>

    init(actionRegistry: ActionRegistry) {
        self.actionRegistry = actionRegistry
        _enabledActionIDs = State(initialValue: Set(actionRegistry.actions.map(\.id)))
    }

    var body: some View {
        Form {
            Section("Actions") {
                ForEach(actionRegistry.actions) { action in
                    Toggle(isOn: binding(for: action.id)) {
                        Label(action.title, systemImage: action.systemImageName)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .padding(18)
    }

    private func binding(for actionID: ActionIdentifier) -> Binding<Bool> {
        Binding(
            get: {
                enabledActionIDs.contains(actionID)
            },
            set: { isEnabled in
                if isEnabled {
                    enabledActionIDs.insert(actionID)
                } else {
                    enabledActionIDs.remove(actionID)
                }
            }
        )
    }
}
