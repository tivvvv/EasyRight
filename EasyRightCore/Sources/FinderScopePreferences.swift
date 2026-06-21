import Foundation

/// Finder 监听范围定义扩展可出现的目录根节点.
public struct FinderScopePreferences: Equatable, Sendable {
    public var directoryPaths: [String]

    public init(
        directoryPaths: [String],
        fallbackDirectoryPath: String = Self.defaultDirectoryPath
    ) {
        let normalizedDirectoryPaths = Self.normalizedDirectoryPaths(directoryPaths)
        if normalizedDirectoryPaths.isEmpty {
            self.directoryPaths = [
                Self.normalizedDirectoryPath(fallbackDirectoryPath),
            ]
        } else {
            self.directoryPaths = normalizedDirectoryPaths
        }
    }

    public static var defaultDirectoryPath: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    public var directoryURLs: [URL] {
        directoryPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public mutating func addDirectory(at path: String) {
        self = FinderScopePreferences(
            directoryPaths: directoryPaths + [path],
            fallbackDirectoryPath: fallbackDirectoryPath
        )
    }

    public mutating func removeDirectory(at path: String) {
        guard directoryPaths.count > 1 else {
            return
        }

        let normalizedPath = Self.normalizedDirectoryPath(path)
        self = FinderScopePreferences(
            directoryPaths: directoryPaths.filter { $0 != normalizedPath },
            fallbackDirectoryPath: fallbackDirectoryPath
        )
    }

    private var fallbackDirectoryPath: String {
        directoryPaths.first ?? Self.defaultDirectoryPath
    }

    private static func normalizedDirectoryPaths(_ paths: [String]) -> [String] {
        var seenPaths = Set<String>()

        return paths.compactMap { path in
            guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let normalizedPath = normalizedDirectoryPath(path)
            guard seenPaths.insert(normalizedPath).inserted else {
                return nil
            }

            return normalizedPath
        }
    }

    private static func normalizedDirectoryPath(_ path: String) -> String {
        URL(
            fileURLWithPath: (path as NSString).expandingTildeInPath,
            isDirectory: true
        )
        .standardizedFileURL
        .path
    }
}

/// Finder 监听范围存储负责在主 App 和 Finder Extension 之间共享目录设置.
public final class FinderScopePreferencesStore: @unchecked Sendable {
    public static let didChangeNotification = Notification.Name(
        "FinderScopePreferencesStore.didChangeNotification"
    )
    public static let didChangeDarwinNotificationName = "com.tiv.EasyRight.finderScopePreferencesDidChange"
    public static let shared = FinderScopePreferencesStore(
        userDefaults: UserDefaults(
            suiteName: ActionPreferencesStore.appGroupIdentifier
        ) ?? .standard
    )

    private enum Key {
        static let directoryPaths = "finderScope.directoryPaths"
    }

    private let userDefaults: UserDefaults
    private let defaultDirectoryPath: String

    public init(
        userDefaults: UserDefaults,
        defaultDirectoryPath: String = FinderScopePreferences.defaultDirectoryPath
    ) {
        self.userDefaults = userDefaults
        self.defaultDirectoryPath = defaultDirectoryPath
    }

    public var defaultPreferences: FinderScopePreferences {
        FinderScopePreferences(
            directoryPaths: [defaultDirectoryPath],
            fallbackDirectoryPath: defaultDirectoryPath
        )
    }

    public func preferences() -> FinderScopePreferences {
        FinderScopePreferences(
            directoryPaths: userDefaults.stringArray(forKey: Key.directoryPaths)
                ?? [defaultDirectoryPath],
            fallbackDirectoryPath: defaultDirectoryPath
        )
    }

    public func save(_ preferences: FinderScopePreferences) {
        let normalizedPreferences = FinderScopePreferences(
            directoryPaths: preferences.directoryPaths,
            fallbackDirectoryPath: defaultDirectoryPath
        )
        userDefaults.set(
            normalizedPreferences.directoryPaths,
            forKey: Key.directoryPaths
        )
        userDefaults.synchronize()
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Self.didChangeDarwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    @discardableResult
    public func reset() -> FinderScopePreferences {
        let defaultPreferences = defaultPreferences
        save(defaultPreferences)
        return defaultPreferences
    }
}
