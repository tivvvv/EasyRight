import Foundation

/// 描述一个 Finder 菜单动作, 具体执行逻辑会在执行层中单独实现.
public struct RightClickActionDescriptor: Identifiable, Hashable, Sendable {
    public let id: ActionIdentifier
    public let title: String
    public let systemImageName: String
    public let selectionRule: SelectionRule

    public init(
        id: ActionIdentifier,
        title: String,
        systemImageName: String,
        selectionRule: SelectionRule
    ) {
        self.id = id
        self.title = title
        self.systemImageName = systemImageName
        self.selectionRule = selectionRule
    }

    public func isAvailable(for selection: FileSelection) -> Bool {
        selectionRule.allows(selection)
    }
}

public enum SelectionRule: String, Hashable, Codable, Sendable {
    case anySelection
    case nonEmptySelection
    case singleItem
    case directorySelection
    case singleFile
    case singleDirectory
    case filesOnly
    case directoriesOnly
    case multipleItems

    public func allows(_ selection: FileSelection) -> Bool {
        switch self {
        case .anySelection:
            return true
        case .nonEmptySelection:
            return !selection.isEmpty
        case .singleItem:
            return selection.isSingleItem
        case .directorySelection:
            return selection.containsDirectory
        case .singleFile:
            return selection.isSingleItem && selection.containsOnlyFiles
        case .singleDirectory:
            return selection.isSingleItem && selection.containsOnlyDirectories
        case .filesOnly:
            return selection.containsOnlyFiles
        case .directoriesOnly:
            return selection.containsOnlyDirectories
        case .multipleItems:
            return selection.isMultipleItems
        }
    }
}
