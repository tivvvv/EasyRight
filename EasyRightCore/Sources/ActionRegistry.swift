import Foundation

/// 动作注册表是菜单定义的唯一入口, 后续设置页会基于这里做排序和开关.
public struct ActionRegistry: Sendable {
    public static let standard = ActionRegistry(actions: [
        .copyPath,
        .copyFileName,
        .copyDirectoryPath,
        .createFile,
        .createFolder,
        .openTerminalHere,
        .openWithCode,
    ])

    public let actions: [RightClickActionDescriptor]

    public init(actions: [RightClickActionDescriptor]) {
        self.actions = actions
    }

    public func availableActions(for selection: FileSelection) -> [RightClickActionDescriptor] {
        actions.filter { $0.isAvailable(for: selection) }
    }

    public func action(with id: ActionIdentifier) -> RightClickActionDescriptor? {
        actions.first { $0.id == id }
    }
}

public extension RightClickActionDescriptor {
    static let copyPath = RightClickActionDescriptor(
        id: .copyPath,
        title: "Copy Path",
        systemImageName: "doc.on.doc",
        selectionRule: .nonEmptySelection
    )

    static let copyFileName = RightClickActionDescriptor(
        id: .copyFileName,
        title: "Copy File Name",
        systemImageName: "textformat",
        selectionRule: .nonEmptySelection
    )

    static let copyDirectoryPath = RightClickActionDescriptor(
        id: .copyDirectoryPath,
        title: "Copy Directory Path",
        systemImageName: "folder",
        selectionRule: .nonEmptySelection
    )

    static let createFile = RightClickActionDescriptor(
        id: .createFile,
        title: "Create File",
        systemImageName: "doc.badge.plus",
        selectionRule: .singleItem
    )

    static let createFolder = RightClickActionDescriptor(
        id: .createFolder,
        title: "Create Folder",
        systemImageName: "folder.badge.plus",
        selectionRule: .singleItem
    )

    static let openTerminalHere = RightClickActionDescriptor(
        id: .openTerminalHere,
        title: "Open Terminal Here",
        systemImageName: "terminal",
        selectionRule: .nonEmptySelection
    )

    static let openWithCode = RightClickActionDescriptor(
        id: .openWithCode,
        title: "Open With VS Code",
        systemImageName: "curlybraces",
        selectionRule: .nonEmptySelection
    )
}
