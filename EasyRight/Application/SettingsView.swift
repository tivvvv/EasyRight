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
            Section {
                ForEach(orderedActions) { action in
                    HStack(spacing: 12) {
                        Toggle(isOn: binding(for: action.id)) {
                            Label(action.title, systemImage: action.systemImageName)
                                .opacity(isEnabled(action.id) ? 1 : 0.45)
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
            } header: {
                HStack {
                    Text("Actions")

                    Text(enabledActionSummary)
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

            Section {
                ForEach(finderScopePreferences.directoryPaths, id: \.self) { directoryPath in
                    HStack(spacing: 12) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(forDirectoryPath: directoryPath))

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
                            removeScopeDirectory(at: directoryPath)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .accessibilityLabel("Remove Folder")
                        .disabled(!canRemoveScopeDirectory)
                        .buttonStyle(.borderless)
                    }
                }

                Button {
                    addScopeDirectories()
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            } header: {
                HStack {
                    Text("Finder Scope")

                    Text(finderScopeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        resetScopeDefaults()
                    } label: {
                        Label("Reset Scope", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!canResetScopeDefaults)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
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

    private func displayName(forDirectoryPath directoryPath: String) -> String {
        let url = URL(fileURLWithPath: directoryPath, isDirectory: true)

        return url.lastPathComponent.isEmpty ? directoryPath : url.lastPathComponent
    }
}
