import AppKit
import Foundation

public struct FileNamePromptResult: Equatable, Sendable {
    public let baseName: String
    public let fileExtension: String

    public init(baseName: String, fileExtension: String) {
        self.baseName = baseName
        self.fileExtension = fileExtension
    }
}

/// 名称输入能力独立成协议, 让创建动作可以替换交互依赖.
public protocol ItemNamePrompting: AnyObject {
    func promptForFileName(
        title: String,
        message: String,
        defaultBaseName: String,
        defaultFileExtension: String
    ) throws -> FileNamePromptResult

    func promptForFolderName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String
}

/// 系统名称输入器负责展示创建动作的命名弹窗.
public final class SystemItemNamePrompter: ItemNamePrompting {
    public init() {}

    public func promptForFileName(
        title: String,
        message: String,
        defaultBaseName: String,
        defaultFileExtension: String
    ) throws -> FileNamePromptResult {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated {
                try Self.runFilePrompt(
                    title: title,
                    message: message,
                    defaultBaseName: defaultBaseName,
                    defaultFileExtension: defaultFileExtension
                )
            }
        }

        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated {
                try Self.runFilePrompt(
                    title: title,
                    message: message,
                    defaultBaseName: defaultBaseName,
                    defaultFileExtension: defaultFileExtension
                )
            }
        }
    }

    public func promptForFolderName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated {
                try Self.runFolderPrompt(
                    title: title,
                    message: message,
                    defaultName: defaultName
                )
            }
        }

        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated {
                try Self.runFolderPrompt(
                    title: title,
                    message: message,
                    defaultName: defaultName
                )
            }
        }
    }

    @MainActor
    private static func runFilePrompt(
        title: String,
        message: String,
        defaultBaseName: String,
        defaultFileExtension: String
    ) throws -> FileNamePromptResult {
        let baseNameField = makeTextField(defaultValue: defaultBaseName, width: 260)
        let fileExtensionField = makeTextField(defaultValue: defaultFileExtension, width: 120)
        fileExtensionField.placeholderString = "Optional"
        let gridView = NSGridView(views: [
            [
                NSTextField(labelWithString: "Name"),
                baseNameField,
            ],
            [
                NSTextField(labelWithString: "Extension"),
                fileExtensionField,
            ],
        ])
        gridView.column(at: 0).xPlacement = .trailing
        gridView.column(at: 1).xPlacement = .fill
        gridView.rowSpacing = 8
        gridView.columnSpacing = 8
        gridView.setFrameSize(NSSize(width: 360, height: 56))
        baseNameField.selectText(nil)

        let response = runAlert(
            title: title,
            message: message,
            accessoryView: gridView
        )

        guard response == .alertFirstButtonReturn else {
            throw ActionExecutionError.nameInputCancelled
        }

        return FileNamePromptResult(
            baseName: baseNameField.stringValue,
            fileExtension: fileExtensionField.stringValue
        )
    }

    @MainActor
    private static func runFolderPrompt(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        let textField = makeTextField(defaultValue: defaultName, width: 320)
        textField.selectText(nil)

        let response = runAlert(
            title: title,
            message: message,
            accessoryView: textField
        )

        guard response == .alertFirstButtonReturn else {
            throw ActionExecutionError.nameInputCancelled
        }

        return textField.stringValue
    }

    @MainActor
    private static func makeTextField(defaultValue: String, width: CGFloat) -> NSTextField {
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: 24))
        textField.stringValue = defaultValue
        return textField
    }

    @MainActor
    private static func runAlert(
        title: String,
        message: String,
        accessoryView: NSView
    ) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal()
    }
}
