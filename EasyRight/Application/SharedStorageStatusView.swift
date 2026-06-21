import SwiftUI

import EasyRightCore

struct SharedStorageStatusLabel: View {
    let diagnostic: SharedSettingsStorageDiagnostic

    var body: some View {
        Label(diagnostic.displayTitle, systemImage: diagnostic.systemImageName)
            .foregroundStyle(diagnostic.foregroundStyle)
    }
}

struct SharedStorageStatusDetail: View {
    let diagnostic: SharedSettingsStorageDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SharedStorageStatusLabel(diagnostic: diagnostic)

            Text(diagnostic.suiteName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

extension SharedSettingsStorageDiagnostic {
    var displayTitle: String {
        switch location {
        case .appGroup:
            "Shared storage active"
        case .standardFallback:
            "Using local storage"
        case .custom:
            "Custom storage"
        }
    }

    var systemImageName: String {
        switch location {
        case .appGroup:
            "checkmark.circle"
        case .standardFallback:
            "exclamationmark.triangle"
        case .custom:
            "gearshape"
        }
    }

    var foregroundStyle: Color {
        switch location {
        case .appGroup:
            .secondary
        case .standardFallback:
            .orange
        case .custom:
            .secondary
        }
    }
}
