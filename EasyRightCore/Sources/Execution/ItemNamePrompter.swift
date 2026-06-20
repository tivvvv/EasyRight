import AppKit
import Foundation

/// 名称输入能力独立成协议, 让创建动作可以替换交互依赖.
public protocol ItemNamePrompting: AnyObject {
    func promptForItemName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String
}

/// 系统名称输入器负责展示创建动作的命名弹窗.
public final class SystemItemNamePrompter: ItemNamePrompting {
    public init() {}

    public func promptForItemName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated {
                try Self.runPrompt(
                    title: title,
                    message: message,
                    defaultName: defaultName
                )
            }
        }

        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated {
                try Self.runPrompt(
                    title: title,
                    message: message,
                    defaultName: defaultName
                )
            }
        }
    }

    @MainActor
    private static func runPrompt(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.stringValue = defaultName
        textField.selectText(nil)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = textField
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            throw ActionExecutionError.nameInputCancelled
        }

        return textField.stringValue
    }
}
