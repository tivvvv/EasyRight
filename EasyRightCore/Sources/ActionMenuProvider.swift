import Foundation

/// 菜单动作提供器集中处理偏好设置, 选择规则和执行器支持范围.
public struct ActionMenuProvider: Sendable {
    public static let standard = ActionMenuProvider(registry: .standard)

    public let registry: ActionRegistry
    public let supportedActionIDs: Set<ActionIdentifier>

    public init(
        registry: ActionRegistry,
        supportedActionIDs: Set<ActionIdentifier> = ActionExecutor.supportedActionIDs
    ) {
        self.registry = registry
        self.supportedActionIDs = supportedActionIDs
    }

    public func actions(
        for selection: FileSelection,
        preferences: ActionPreferences
    ) -> [RightClickActionDescriptor] {
        preferences
            .availableActions(for: selection, in: registry)
            .filter { supportedActionIDs.contains($0.id) }
    }
}
