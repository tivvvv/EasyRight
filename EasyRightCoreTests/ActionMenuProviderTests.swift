import XCTest
@testable import EasyRightCore

final class ActionMenuProviderTests: XCTestCase {
    func testActionsRespectPreferencesOrderAndDisabledState() {
        let registry = ActionRegistry.standard
        let provider = ActionMenuProvider(registry: registry)
        let preferences = ActionPreferences(
            orderedActionIDs: [
                .openWithCode,
                .copyPath,
                .copyFileName,
            ],
            disabledActionIDs: [.copyPath]
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let actionIDs = provider
            .actions(
                for: FileSelection(urls: [selectedURL]),
                preferences: preferences
            )
            .map(\.id)

        XCTAssertEqual(
            actionIDs,
            [
                .openWithCode,
                .copyFileName,
                .copyFileContents,
                .copyDirectoryPath,
                .createFile,
                .createFolder,
                .openWithTerminal,
                .openWithCursor,
            ]
        )
    }

    func testActionsHideSingleSelectionItemsForMultipleSelection() {
        let provider = ActionMenuProvider(registry: .standard)
        let preferences = ActionPreferences.defaults(for: .standard)
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.md")

        let actionIDs = provider
            .actions(
                for: FileSelection(urls: [firstURL, secondURL]),
                preferences: preferences
            )
            .map(\.id)

        XCTAssertFalse(actionIDs.contains(.createFile))
        XCTAssertFalse(actionIDs.contains(.createFolder))
        XCTAssertFalse(actionIDs.contains(.copyFileContents))
        XCTAssertTrue(actionIDs.contains(.copyPath))
        XCTAssertTrue(actionIDs.contains(.openWithCursor))
    }

    func testActionsFilterUnsupportedActions() {
        let unsupportedAction = RightClickActionDescriptor(
            id: ActionIdentifier(rawValue: "unsupported_action"),
            title: "Unsupported Action",
            systemImageName: "questionmark",
            selectionRule: .nonEmptySelection
        )
        let registry = ActionRegistry(actions: [
            .copyPath,
            unsupportedAction,
            .copyFileName,
        ])
        let provider = ActionMenuProvider(
            registry: registry,
            supportedActionIDs: [.copyPath]
        )
        let preferences = ActionPreferences.defaults(for: registry)
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let actionIDs = provider
            .actions(
                for: FileSelection(urls: [selectedURL]),
                preferences: preferences
            )
            .map(\.id)

        XCTAssertEqual(actionIDs, [.copyPath])
    }
}
