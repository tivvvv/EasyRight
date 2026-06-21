import SwiftUI

import EasyRightCore

struct SettingsView: View {
    let actionRegistry: ActionRegistry
    private let preferencesStore: ActionPreferencesStore

    @State private var preferences: ActionPreferences

    init(
        actionRegistry: ActionRegistry,
        preferencesStore: ActionPreferencesStore = .shared
    ) {
        self.actionRegistry = actionRegistry
        self.preferencesStore = preferencesStore
        _preferences = State(
            initialValue: preferencesStore.preferences(for: actionRegistry)
        )
    }

    var body: some View {
        Form {
            Section("Actions") {
                ForEach(orderedActions) { action in
                    HStack(spacing: 12) {
                        Toggle(isOn: binding(for: action.id)) {
                            Label(action.title, systemImage: action.systemImageName)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Button {
                                move(action.id, direction: .up)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .accessibilityLabel("Move Up")
                            .disabled(!canMove(action.id, direction: .up))

                            Button {
                                move(action.id, direction: .down)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .accessibilityLabel("Move Down")
                            .disabled(!canMove(action.id, direction: .down))
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .padding(18)
        .onAppear {
            preferences = preferencesStore.preferences(for: actionRegistry)
        }
    }

    private var orderedActions: [RightClickActionDescriptor] {
        preferences.orderedActions(in: actionRegistry)
    }

    private func binding(for actionID: ActionIdentifier) -> Binding<Bool> {
        Binding(
            get: {
                preferences.isEnabled(actionID)
            },
            set: { isEnabled in
                var nextPreferences = preferences
                nextPreferences.setEnabled(isEnabled, for: actionID)
                updatePreferences(nextPreferences)
            }
        )
    }

    private func move(_ actionID: ActionIdentifier, direction: ActionMoveDirection) {
        var nextPreferences = preferences
        nextPreferences.moveAction(actionID, direction: direction, in: actionRegistry)
        updatePreferences(nextPreferences)
    }

    private func canMove(
        _ actionID: ActionIdentifier,
        direction: ActionMoveDirection
    ) -> Bool {
        let orderedActionIDs = preferences
            .normalized(for: actionRegistry)
            .orderedActionIDs

        guard let index = orderedActionIDs.firstIndex(of: actionID) else {
            return false
        }

        return orderedActionIDs.indices.contains(index + direction.offset)
    }

    private func updatePreferences(_ nextPreferences: ActionPreferences) {
        preferences = nextPreferences.normalized(for: actionRegistry)
        preferencesStore.save(preferences, for: actionRegistry)
    }
}
