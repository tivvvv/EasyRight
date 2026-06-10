import SwiftUI
import EasyRightCore

struct RootView: View {
    let actionRegistry: ActionRegistry

    @State private var selectedActionID: ActionIdentifier?

    var body: some View {
        NavigationSplitView {
            List(actionRegistry.actions, selection: $selectedActionID) { action in
                Label(action.title, systemImage: action.systemImageName)
                    .tag(action.id)
            }
            .navigationTitle("EasyRight")
        } detail: {
            ActionDetailView(action: selectedAction)
        }
        .frame(minWidth: 760, minHeight: 460)
    }

    private var selectedAction: RightClickActionDescriptor? {
        guard let selectedActionID else {
            return actionRegistry.actions.first
        }

        return actionRegistry.actions.first { $0.id == selectedActionID }
    }
}

private struct ActionDetailView: View {
    let action: RightClickActionDescriptor?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let action {
                Label(action.title, systemImage: action.systemImageName)
                    .font(.title2.weight(.semibold))

                Text("Identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(action.id.rawValue)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text("EasyRight")
                    .font(.title2.weight(.semibold))
            }

            Spacer()
        }
        .padding(28)
    }
}
