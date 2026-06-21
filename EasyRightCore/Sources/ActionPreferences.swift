import Foundation

/// 动作偏好描述菜单顺序和禁用状态, 新动作默认保持启用.
public struct ActionPreferences: Equatable, Sendable {
    public var orderedActionIDs: [ActionIdentifier]
    public var disabledActionIDs: Set<ActionIdentifier>

    public init(
        orderedActionIDs: [ActionIdentifier],
        disabledActionIDs: Set<ActionIdentifier>
    ) {
        self.orderedActionIDs = orderedActionIDs
        self.disabledActionIDs = disabledActionIDs
    }

    public static func defaults(for registry: ActionRegistry) -> ActionPreferences {
        ActionPreferences(
            orderedActionIDs: registry.actions.map(\.id),
            disabledActionIDs: []
        )
    }

    public func normalized(for registry: ActionRegistry) -> ActionPreferences {
        let registeredActionIDs = registry.actions.map(\.id)
        let registeredActionIDSet = Set(registeredActionIDs)
        var seenActionIDs = Set<ActionIdentifier>()
        let keptActionIDs = orderedActionIDs.filter { actionID in
            registeredActionIDSet.contains(actionID) && seenActionIDs.insert(actionID).inserted
        }
        let missingActionIDs = registeredActionIDs.filter { !seenActionIDs.contains($0) }

        return ActionPreferences(
            orderedActionIDs: keptActionIDs + missingActionIDs,
            disabledActionIDs: disabledActionIDs.intersection(registeredActionIDSet)
        )
    }

    public func isEnabled(_ actionID: ActionIdentifier) -> Bool {
        !disabledActionIDs.contains(actionID)
    }

    public func enabledActionCount(in registry: ActionRegistry) -> Int {
        let normalizedPreferences = normalized(for: registry)

        return normalizedPreferences.orderedActionIDs
            .filter { normalizedPreferences.isEnabled($0) }
            .count
    }

    public mutating func setEnabled(_ isEnabled: Bool, for actionID: ActionIdentifier) {
        if isEnabled {
            disabledActionIDs.remove(actionID)
        } else {
            disabledActionIDs.insert(actionID)
        }
    }

    public mutating func moveAction(
        _ actionID: ActionIdentifier,
        direction: ActionMoveDirection,
        in registry: ActionRegistry
    ) {
        self = normalized(for: registry)

        guard let sourceIndex = orderedActionIDs.firstIndex(of: actionID) else {
            return
        }

        let destinationIndex = sourceIndex + direction.offset
        guard orderedActionIDs.indices.contains(destinationIndex) else {
            return
        }

        orderedActionIDs.swapAt(sourceIndex, destinationIndex)
    }

    public func orderedActions(in registry: ActionRegistry) -> [RightClickActionDescriptor] {
        let normalizedPreferences = normalized(for: registry)
        let actionsByID = Dictionary(uniqueKeysWithValues: registry.actions.map { ($0.id, $0) })

        return normalizedPreferences.orderedActionIDs.compactMap { actionsByID[$0] }
    }

    public func availableActions(
        for selection: FileSelection,
        in registry: ActionRegistry
    ) -> [RightClickActionDescriptor] {
        orderedActions(in: registry)
            .filter { isEnabled($0.id) }
            .filter { $0.isAvailable(for: selection) }
    }
}

public enum ActionMoveDirection: Sendable {
    case up
    case down

    public var offset: Int {
        switch self {
        case .up:
            -1
        case .down:
            1
        }
    }
}

/// 动作偏好存储负责在主 App 和 Finder Extension 之间共享设置.
public final class ActionPreferencesStore: @unchecked Sendable {
    public static let appGroupIdentifier = "group.com.tiv.EasyRight"
    public static let shared = ActionPreferencesStore(
        userDefaults: UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    )

    private enum Key {
        static let orderedActionIDs = "actionPreferences.orderedActionIDs"
        static let disabledActionIDs = "actionPreferences.disabledActionIDs"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public func preferences(for registry: ActionRegistry) -> ActionPreferences {
        let orderedActionIDs = userDefaults
            .stringArray(forKey: Key.orderedActionIDs)?
            .map(ActionIdentifier.init(rawValue:)) ?? registry.actions.map(\.id)
        let disabledActionIDs = Set(
            userDefaults
                .stringArray(forKey: Key.disabledActionIDs)?
                .map(ActionIdentifier.init(rawValue:)) ?? []
        )

        return ActionPreferences(
            orderedActionIDs: orderedActionIDs,
            disabledActionIDs: disabledActionIDs
        )
        .normalized(for: registry)
    }

    public func save(_ preferences: ActionPreferences, for registry: ActionRegistry) {
        let normalizedPreferences = preferences.normalized(for: registry)
        userDefaults.set(
            normalizedPreferences.orderedActionIDs.map(\.rawValue),
            forKey: Key.orderedActionIDs
        )
        userDefaults.set(
            normalizedPreferences.disabledActionIDs.map(\.rawValue).sorted(),
            forKey: Key.disabledActionIDs
        )
        userDefaults.synchronize()
    }

    @discardableResult
    public func reset(for registry: ActionRegistry) -> ActionPreferences {
        let defaultPreferences = ActionPreferences.defaults(for: registry)
        save(defaultPreferences, for: registry)
        return defaultPreferences
    }
}
