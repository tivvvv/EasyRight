import FinderSync
import SwiftUI

import EasyRightCore

struct RootView: View {
    let actionRegistry: ActionRegistry
    private let preferencesStore: ActionPreferencesStore
    private let finderScopePreferencesStore: FinderScopePreferencesStore

    @State private var preferences: ActionPreferences
    @State private var finderScopePreferences: FinderScopePreferences
    @State private var selectedActionID: ActionIdentifier?

    init(
        actionRegistry: ActionRegistry,
        preferencesStore: ActionPreferencesStore = .shared,
        finderScopePreferencesStore: FinderScopePreferencesStore = .shared
    ) {
        self.actionRegistry = actionRegistry
        self.preferencesStore = preferencesStore
        self.finderScopePreferencesStore = finderScopePreferencesStore

        let initialPreferences = preferencesStore.preferences(for: actionRegistry)
        let initialFinderScopePreferences = finderScopePreferencesStore.preferences()
        _preferences = State(initialValue: initialPreferences)
        _finderScopePreferences = State(initialValue: initialFinderScopePreferences)
        _selectedActionID = State(
            initialValue: initialPreferences.orderedActionIDs.first
        )
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(orderedActions, selection: $selectedActionID) { action in
                    HStack(spacing: 10) {
                        Label(action.title, systemImage: action.systemImageName)
                            .opacity(preferences.isEnabled(action.id) ? 1 : 0.45)

                        Spacer()

                        if !preferences.isEnabled(action.id) {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Disabled")
                        }
                    }
                    .tag(action.id)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label(enabledActionSummary, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(finderScopeSummary, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SettingsLink {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .navigationTitle("EasyRight")
        } detail: {
            ActionDetailView(
                action: selectedAction,
                isEnabled: selectedAction.map { preferences.isEnabled($0.id) } ?? false,
                enabledActionSummary: enabledActionSummary,
                finderScopeSummary: finderScopeSummary
            )
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear {
            refreshPreferences()
            refreshFinderScopePreferences()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ActionPreferencesStore.didChangeNotification
            )
        ) { _ in
            refreshPreferences()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: FinderScopePreferencesStore.didChangeNotification
            )
        ) { _ in
            refreshFinderScopePreferences()
        }
    }

    private var orderedActions: [RightClickActionDescriptor] {
        preferences.orderedActions(in: actionRegistry)
    }

    private var selectedAction: RightClickActionDescriptor? {
        guard let selectedActionID else {
            return orderedActions.first
        }

        return orderedActions.first { $0.id == selectedActionID }
    }

    private var enabledActionSummary: String {
        let enabledCount = preferences.enabledActionCount(in: actionRegistry)
        let totalCount = preferences.normalized(for: actionRegistry).orderedActionIDs.count

        return "\(enabledCount) of \(totalCount) enabled"
    }

    private var finderScopeSummary: String {
        let count = finderScopePreferences.directoryPaths.count
        let noun = count == 1 ? "folder" : "folders"

        return "\(count) Finder scope \(noun)"
    }

    private func refreshPreferences() {
        let nextPreferences = preferencesStore.preferences(for: actionRegistry)
        preferences = nextPreferences

        guard
            let selectedActionID,
            nextPreferences.orderedActionIDs.contains(selectedActionID)
        else {
            selectedActionID = nextPreferences.orderedActionIDs.first
            return
        }
    }

    private func refreshFinderScopePreferences() {
        finderScopePreferences = finderScopePreferencesStore.preferences()
    }
}

private struct ActionDetailView: View {
    let action: RightClickActionDescriptor?
    let isEnabled: Bool
    let enabledActionSummary: String
    let finderScopeSummary: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                Divider()

                if let action {
                    actionSummary(action)
                } else {
                    emptySummary
                }

                Divider()

                integrationActions
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 28))
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("EasyRight")
                        .font(.title2.weight(.semibold))

                    Text(enabledActionSummary)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private func actionSummary(_ action: RightClickActionDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(action.title, systemImage: action.systemImageName)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(
                    title: "Status",
                    value: isEnabled ? "Enabled" : "Disabled",
                    systemImageName: isEnabled ? "checkmark.circle" : "minus.circle"
                )

                DetailRow(
                    title: "Selection",
                    value: action.selectionRule.displayTitle,
                    systemImageName: "filemenu.and.selection"
                )

                DetailRow(
                    title: "Scope",
                    value: finderScopeSummary,
                    systemImageName: "folder"
                )

                DetailRow(
                    title: "Identifier",
                    value: action.id.rawValue,
                    systemImageName: "number",
                    usesMonospacedValue: true
                )
            }
        }
    }

    private var emptySummary: some View {
        Label("No Action Selected", systemImage: "questionmark.circle")
            .font(.title3.weight(.semibold))
    }

    private var integrationActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Integrations")
                .font(.headline)

            HStack(spacing: 12) {
                SettingsLink {
                    Label("Action Settings", systemImage: "slider.horizontal.3")
                }

                Button {
                    openFinderExtensionSettings()
                } label: {
                    Label("Finder Extension", systemImage: "puzzlepiece.extension")
                }
            }
            .controlSize(.large)
        }
    }

    private func openFinderExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    let systemImageName: String
    var usesMonospacedValue = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImageName)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(title)
                .frame(width: 92, alignment: .leading)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(usesMonospacedValue ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
    }
}

private extension SelectionRule {
    var displayTitle: String {
        switch self {
        case .anySelection:
            "Any selection"
        case .nonEmptySelection:
            "One or more items"
        case .singleItem:
            "Single item"
        case .directorySelection:
            "Directory"
        }
    }
}
