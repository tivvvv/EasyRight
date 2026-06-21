import XCTest
@testable import EasyRightCore

final class FinderScopePreferencesTests: XCTestCase {
    func testPreferencesNormalizeDirectoryPathsAndRemoveDuplicates() {
        let expectedPath = URL(
            fileURLWithPath: "/tmp/EasyRight",
            isDirectory: true
        )
        .standardizedFileURL
        .path
        let preferences = FinderScopePreferences(
            directoryPaths: [
                "",
                "/tmp/../tmp/EasyRight",
                "/tmp/EasyRight/",
                "~/Documents",
            ],
            fallbackDirectoryPath: "/Users/example"
        )

        XCTAssertEqual(preferences.directoryPaths.first, expectedPath)
        XCTAssertEqual(preferences.directoryPaths.count, 2)
    }

    func testPreferencesFallbackToDefaultDirectoryWhenEmpty() {
        let preferences = FinderScopePreferences(
            directoryPaths: [],
            fallbackDirectoryPath: "/Users/example"
        )

        XCTAssertEqual(preferences.directoryPaths, ["/Users/example"])
    }

    func testPreferencesKeepAtLeastOneDirectoryWhenRemoving() {
        var preferences = FinderScopePreferences(
            directoryPaths: ["/Users/example"],
            fallbackDirectoryPath: "/Users/example"
        )

        preferences.removeDirectory(at: "/Users/example")

        XCTAssertEqual(preferences.directoryPaths, ["/Users/example"])
    }

    func testStoreRoundTripsNormalizedScopePreferences() {
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = FinderScopePreferencesStore(
            userDefaults: userDefaults,
            defaultDirectoryPath: "/Users/example"
        )
        let preferences = FinderScopePreferences(
            directoryPaths: [
                "/tmp/../tmp/EasyRight",
                "/tmp/EasyRight",
            ],
            fallbackDirectoryPath: "/Users/example"
        )

        store.save(preferences)
        let storedPreferences = store.preferences()

        XCTAssertEqual(storedPreferences.directoryPaths.count, 1)
        XCTAssertEqual(storedPreferences.directoryPaths, preferences.directoryPaths)
    }

    func testStorePostsChangeNotificationWhenSavingScopePreferences() {
        let suiteName = "EasyRightCoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = FinderScopePreferencesStore(
            userDefaults: userDefaults,
            defaultDirectoryPath: "/Users/example"
        )
        let expectation = expectation(description: "Store posts scope change notification.")
        let observer = NotificationCenter.default.addObserver(
            forName: FinderScopePreferencesStore.didChangeNotification,
            object: store,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        store.save(
            FinderScopePreferences(
                directoryPaths: ["/tmp/EasyRight"],
                fallbackDirectoryPath: "/Users/example"
            )
        )

        wait(for: [expectation], timeout: 1)
    }
}
