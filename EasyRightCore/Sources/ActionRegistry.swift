import Foundation

/// 动作注册表是菜单定义的唯一入口, 设置页和 Finder 菜单都会读取这里.
public struct ActionRegistry: Sendable {
    public static let standard = ActionRegistry(actions: [
        .copyPath,
        .copyFileName,
        .copyDirectoryPath,
        .createFile,
        .createFolder,
        .openWithTerminal,
        .openWithCursor,
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

    static let openWithTerminal = RightClickActionDescriptor(
        id: .openWithTerminal,
        title: "Open With Terminal",
        systemImageName: "terminal",
        selectionRule: .nonEmptySelection
    )

    static let openTerminalHere = openWithTerminal

    static let openWithCursor = RightClickActionDescriptor(
        id: .openWithCursor,
        title: "Open With Cursor",
        systemImageName: "cursorarrow",
        selectionRule: .nonEmptySelection
    )

    static let openWithCode = RightClickActionDescriptor(
        id: .openWithCode,
        title: "Open With VS Code",
        systemImageName: "curlybraces",
        selectionRule: .nonEmptySelection
    )
}
