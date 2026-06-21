import AppKit
import Foundation

/// Cursor 打开能力独立成协议, 让执行器可以替换编辑器依赖.
public protocol CursorOpening: AnyObject {
    func openCursor(at itemURLs: [URL]) throws
}

/// 系统 Cursor 打开器负责把文件和目录交给 Cursor.app 处理.
public final class SystemCursorOpener: CursorOpening {
    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let cursorBundleIdentifier = "com.todesktop.230313mzl4w4u92"
    private let fallbackApplicationURLs: [URL]

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
        self.fallbackApplicationURLs = [
            URL(fileURLWithPath: "/Applications/Cursor.app", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/Cursor.app", isDirectory: true),
        ]
    }

    public func openCursor(at itemURLs: [URL]) throws {
        guard let cursorURL = cursorApplicationURL else {
            throw ActionExecutionError.cursorApplicationNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        workspace.open(
            itemURLs,
            withApplicationAt: cursorURL,
            configuration: configuration,
            completionHandler: nil
        )
    }

    private var cursorApplicationURL: URL? {
        workspace.urlForApplication(withBundleIdentifier: cursorBundleIdentifier)
            ?? fallbackApplicationURLs.first { fileManager.fileExists(atPath: $0.path) }
    }
}
