import XCTest
@testable import EasyRightCore

final class ActionPreferencesTests: XCTestCase {
    func testDefaultPreferencesEnableActionsInRegistryOrder() {
        let registry = ActionRegistry.standard
        let preferences = ActionPreferences.defaults(for: registry)

        XCTAssertEqual(preferences.orderedActionIDs, registry.actions.map(\.id))
        XCTAssertTrue(preferences.disabledActionIDs.isEmpty)
        XCTAssertEqual(
            preferences.orderedActions(in: registry).map(\.id),
            registry.actions.map(\.id)
        )
    }

    func testAvailableActionsRespectDisabledStateAndOrder() {
        let registry = ActionRegistry.standard
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")
        let preferences = ActionPreferences(
            orderedActionIDs: [
                .openWithCode,
                .copyPath,
                .copyFileName,
                .createFile,
            ],
            disabledActionIDs: [.copyPath]
        )

        let actionIDs = preferences
            .availableActions(
                for: FileSelection(urls: [selectedURL]),
                in: registry
            )
            .map(\.id)

        XCTAssertEqual(
            actionIDs,
            [
                .openWithCode,
                .copyFileName,
                .createFile,
                .copyDirectoryPath,
                .createFolder,
                .openWithTerminal,
                .openWithCursor,
            ]
        )
    }

    func testNormalizationRemovesUnknownActionsAndAppendsNewActions() {
        let registry = ActionRegistry(actions: [
            .copyPath,
            .copyFileName,
            .openWithTerminal,
        ])
        let unknownActionID = ActionIdentifier(rawValue: "missing_action")
        let preferences = ActionPreferences(
            orderedActionIDs: [
                .copyFileName,
                unknownActionID,
                .copyFileName,
            ],
            disabledActionIDs: [.copyPath, unknownActionID]
        )

        let normalizedPreferences = preferences.normalized(for: registry)

        XCTAssertEqual(
            normalizedPreferences.orderedActionIDs,
            [
                .copyFileName,
                .copyPath,
                .openWithTerminal,
            ]
        )
        XCTAssertEqual(normalizedPreferences.disabledActionIDs, [.copyPath])
    }

    func testMoveActionChangesOrderWithinBounds() {
        let registry = ActionRegistry(actions: [
            .copyPath,
            .copyFileName,
            .openWithTerminal,
        ])
        var preferences = ActionPreferences.defaults(for: registry)

        preferences.moveAction(.openWithTerminal, direction: .up, in: registry)
        preferences.moveAction(.copyPath, direction: .up, in: registry)
        preferences.moveAction(.copyPath, direction: .down, in: registry)

        XCTAssertEqual(
            preferences.orderedActionIDs,
            [
                .openWithTerminal,
                .copyPath,
                .copyFileName,
            ]
        )
    }

    func testEnabledActionCountUsesNormalizedPreferences() {
        let registry = ActionRegistry(actions: [
            .copyPath,
            .copyFileName,
            .openWithTerminal,
        ])
        let unknownActionID = ActionIdentifier(rawValue: "missing_action")
        let preferences = ActionPreferences(
            orderedActionIDs: [
                .copyPath,
                unknownActionID,
            ],
            disabledActionIDs: [
                .copyPath,
                unknownActionID,
            ]
        )

        XCTAssertEqual(preferences.enabledActionCount(in: registry), 2)
    }

    func testStoreRoundTripsNormalizedPreferences() {
        let registry = ActionRegistry.standard
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = ActionPreferencesStore(userDefaults: userDefaults)
        let preferences = ActionPreferences(
            orderedActionIDs: [
                .openWithCode,
                .copyPath,
            ],
            disabledActionIDs: [.copyPath]
        )

        store.save(preferences, for: registry)
        let storedPreferences = store.preferences(for: registry)

        XCTAssertEqual(storedPreferences.orderedActionIDs.first, .openWithCode)
        XCTAssertTrue(storedPreferences.disabledActionIDs.contains(.copyPath))
        XCTAssertEqual(Set(storedPreferences.orderedActionIDs), Set(registry.actions.map(\.id)))
    }

    func testStoreExposesStorageDiagnostic() {
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let diagnostic = SharedSettingsStorageDiagnostic(
            suiteName: suiteName,
            location: .appGroup
        )
        let store = ActionPreferencesStore(
            userDefaults: userDefaults,
            storageDiagnostic: diagnostic
        )

        XCTAssertEqual(store.storageDiagnostic, diagnostic)
        XCTAssertTrue(store.storageDiagnostic.usesAppGroup)
    }

    func testStorePostsChangeNotificationWhenSavingPreferences() {
        let registry = ActionRegistry.standard
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = ActionPreferencesStore(userDefaults: userDefaults)
        let expectation = expectation(description: "Store posts change notification.")
        let observer = NotificationCenter.default.addObserver(
            forName: ActionPreferencesStore.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.save(
            ActionPreferences(
                orderedActionIDs: [.copyPath],
                disabledActionIDs: [.copyPath]
            ),
            for: registry
        )

        wait(for: [expectation], timeout: 1)
    }

    func testStoreResetsPreferencesToDefaults() {
        let registry = ActionRegistry.standard
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = ActionPreferencesStore(userDefaults: userDefaults)
        let customPreferences = ActionPreferences(
            orderedActionIDs: [
                .openWithCode,
                .copyPath,
            ],
            disabledActionIDs: [.copyPath]
        )

        store.save(customPreferences, for: registry)
        let resetPreferences = store.reset(for: registry)
        let storedPreferences = store.preferences(for: registry)

        XCTAssertEqual(resetPreferences, ActionPreferences.defaults(for: registry))
        XCTAssertEqual(storedPreferences, ActionPreferences.defaults(for: registry))
    }
}
