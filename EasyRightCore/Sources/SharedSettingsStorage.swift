import Foundation

/// 共享设置存储诊断用于暴露 App Group 是否可用.
public struct SharedSettingsStorageDiagnostic: Equatable, Sendable {
    public enum Location: String, Sendable {
        case appGroup
        case standardFallback
        case custom
    }

    public let suiteName: String
    public let location: Location

    public init(suiteName: String, location: Location) {
        self.suiteName = suiteName
        self.location = location
    }

    public var usesAppGroup: Bool {
        location == .appGroup
    }
}

struct SharedSettingsUserDefaults {
    let userDefaults: UserDefaults
    let diagnostic: SharedSettingsStorageDiagnostic

    static func make(suiteName: String) -> SharedSettingsUserDefaults {
        if let userDefaults = UserDefaults(suiteName: suiteName) {
            return SharedSettingsUserDefaults(
                userDefaults: userDefaults,
                diagnostic: SharedSettingsStorageDiagnostic(
                    suiteName: suiteName,
                    location: .appGroup
                )
            )
        }

        return SharedSettingsUserDefaults(
            userDefaults: .standard,
            diagnostic: SharedSettingsStorageDiagnostic(
                suiteName: suiteName,
                location: .standardFallback
            )
        )
    }
}
