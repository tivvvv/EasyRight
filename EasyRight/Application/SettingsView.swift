import AppKit
import SwiftUI

import EasyRightCore

struct SettingsView: View {
    let actionRegistry: ActionRegistry
    private let preferencesStore: ActionPreferencesStore
    private let finderScopePreferencesStore: FinderScopePreferencesStore

    @State private var preferences: ActionPreferences
    @State private var finderScopePreferences: FinderScopePreferences

    init(
        actionRegistry: ActionRegistry,
        preferencesStore: ActionPreferencesStore = .shared,
        finderScopePreferencesStore: FinderScopePreferencesStore = .shared
    ) {
        self.actionRegistry = actionRegistry
        self.preferencesStore = preferencesStore
        self.finderScopePreferencesStore = finderScopePreferencesStore
        _preferences = State(
            initialValue: preferencesStore.preferences(for: actionRegistry)
        )
        _finderScopePreferences = State(
            initialValue: finderScopePreferencesStore.preferences()
        )
    }

    var body: some View {
        Form {
            SharedStorageStatusSettingsSection(
                diagnostic: storageDiagnostic
            )

            ActionPreferencesSettingsSection(
                actions: orderedActions,
                summary: enabledActionSummary,
                canResetDefaults: canResetDefaults,
                binding: binding(for:),
                isEnabled: isEnabled(_:),
                canMove: canMove(_:direction:),
                move: move(_:direction:),
                resetDefaults: resetDefaults
            )

            FinderScopeSettingsSection(
                preferences: finderScopePreferences,
                summary: finderScopeSummary,
                canResetDefaults: canResetScopeDefaults,
                canRemoveDirectory: canRemoveScopeDirectory,
                addDirectories: addScopeDirectories,
                removeDirectory: removeScopeDirectory(at:),
                resetDefaults: resetScopeDefaults
            )
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 620)
        .padding(18)
        .onAppear {
            preferences = preferencesStore.preferences(for: actionRegistry)
            finderScopePreferences = finderScopePreferencesStore.preferences()
        }
    }

    private var orderedActions: [RightClickActionDescriptor] {
        preferences.orderedActions(in: actionRegistry)
    }

    private var enabledActionSummary: String {
        let enabledCount = preferences.enabledActionCount(in: actionRegistry)
        let totalCount = preferences.normalized(for: actionRegistry).orderedActionIDs.count

        return "\(enabledCount) of \(totalCount) enabled"
    }

    private var finderScopeSummary: String {
        let count = finderScopePreferences.directoryPaths.count
        let noun = count == 1 ? "folder" : "folders"

        return "\(count) \(noun)"
    }

    private var storageDiagnostic: SharedSettingsStorageDiagnostic {
        preferencesStore.storageDiagnostic
    }

    private var defaultPreferences: ActionPreferences {
        ActionPreferences.defaults(for: actionRegistry)
    }

    private var defaultFinderScopePreferences: FinderScopePreferences {
        finderScopePreferencesStore.defaultPreferences
    }

    private var canResetDefaults: Bool {
        preferences.normalized(for: actionRegistry) != defaultPreferences
    }

    private var canResetScopeDefaults: Bool {
        finderScopePreferences != defaultFinderScopePreferences
    }

    private var canRemoveScopeDirectory: Bool {
        finderScopePreferences.directoryPaths.count > 1
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

    private func isEnabled(_ actionID: ActionIdentifier) -> Bool {
        preferences.isEnabled(actionID)
    }

    private func move(_ actionID: ActionIdentifier, direction: ActionMoveDirection) {
        var nextPreferences = preferences
        nextPreferences.moveAction(actionID, direction: direction, in: actionRegistry)
        updatePreferences(nextPreferences)
    }

    private func resetDefaults() {
        preferences = preferencesStore.reset(for: actionRegistry)
    }

    private func addScopeDirectories() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Add"

        guard panel.runModal() == .OK else {
            return
        }

        var nextPreferences = finderScopePreferences
        panel.urls.forEach { nextPreferences.addDirectory(at: $0.path) }
        updateFinderScopePreferences(nextPreferences)
    }

    private func removeScopeDirectory(at path: String) {
        var nextPreferences = finderScopePreferences
        nextPreferences.removeDirectory(at: path)
        updateFinderScopePreferences(nextPreferences)
    }

    private func resetScopeDefaults() {
        finderScopePreferences = finderScopePreferencesStore.reset()
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

    private func updateFinderScopePreferences(_ nextPreferences: FinderScopePreferences) {
        finderScopePreferences = nextPreferences
        finderScopePreferencesStore.save(finderScopePreferences)
    }
}

private struct SharedStorageStatusSettingsSection: View {
    let diagnostic: SharedSettingsStorageDiagnostic

    var body: some View {
        Section {
            SharedStorageStatusDetail(diagnostic: diagnostic)
        } header: {
            Text("Storage")
        }
    }
}

private struct ActionPreferencesSettingsSection: View {
    let actions: [RightClickActionDescriptor]
    let summary: String
    let canResetDefaults: Bool
    let binding: (ActionIdentifier) -> Binding<Bool>
    let isEnabled: (ActionIdentifier) -> Bool
    let canMove: (ActionIdentifier, ActionMoveDirection) -> Bool
    let move: (ActionIdentifier, ActionMoveDirection) -> Void
    let resetDefaults: () -> Void

    var body: some View {
        Section {
            ForEach(actions) { action in
                ActionPreferenceRow(
                    action: action,
                    isEnabled: isEnabled(action.id),
                    toggleBinding: binding(action.id),
                    canMoveUp: canMove(action.id, .up),
                    canMoveDown: canMove(action.id, .down),
                    moveUp: {
                        move(action.id, .up)
                    },
                    moveDown: {
                        move(action.id, .down)
                    }
                )
            }
        } header: {
            HStack {
                Text("Actions")

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    resetDefaults()
                } label: {
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                .disabled(!canResetDefaults)
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }
}

private struct ActionPreferenceRow: View {
    let action: RightClickActionDescriptor
    let isEnabled: Bool
    let toggleBinding: Binding<Bool>
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: toggleBinding) {
                Label(action.title, systemImage: action.systemImageName)
                    .opacity(isEnabled ? 1 : 0.45)
            }

            Spacer()

            ActionMoveButtons(
                canMoveUp: canMoveUp,
                canMoveDown: canMoveDown,
                moveUp: moveUp,
                moveDown: moveDown
            )
        }
    }
}

private struct ActionMoveButtons: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                moveUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .accessibilityLabel("Move Up")
            .disabled(!canMoveUp)

            Button {
                moveDown()
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Move Down")
            .disabled(!canMoveDown)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

private struct FinderScopeSettingsSection: View {
    let preferences: FinderScopePreferences
    let summary: String
    let canResetDefaults: Bool
    let canRemoveDirectory: Bool
    let addDirectories: () -> Void
    let removeDirectory: (String) -> Void
    let resetDefaults: () -> Void

    var body: some View {
        Section {
            ForEach(preferences.directoryPaths, id: \.self) { directoryPath in
                FinderScopeDirectoryRow(
                    directoryPath: directoryPath,
                    canRemove: canRemoveDirectory,
                    remove: {
                        removeDirectory(directoryPath)
                    }
                )
            }

            Button {
                addDirectories()
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
        } header: {
            HStack {
                Text("Finder Scope")

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    resetDefaults()
                } label: {
                    Label("Reset Scope", systemImage: "arrow.counterclockwise")
                }
                .disabled(!canResetDefaults)
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }
}

private struct FinderScopeDirectoryRow: View {
    let directoryPath: String
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)

                    Text(directoryPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                Image(systemName: "folder")
            }

            Spacer()

            Button {
                remove()
            } label: {
                Image(systemName: "minus.circle")
            }
            .accessibilityLabel("Remove Folder")
            .disabled(!canRemove)
            .buttonStyle(.borderless)
        }
    }

    private var displayName: String {
        let url = URL(fileURLWithPath: directoryPath, isDirectory: true)

        return url.lastPathComponent.isEmpty ? directoryPath : url.lastPathComponent
    }
}
