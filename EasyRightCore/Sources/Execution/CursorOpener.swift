import AppKit
import Foundation

/// Cursor 打开能力独立成协议, 让执行器可以替换编辑器依赖.
public protocol CursorOpening: AnyObject {
    func openCursor(at itemURLs: [URL]) throws
}

/// 系统 Cursor 打开器负责把文件和目录交给 Cursor.app 处理.
public final class SystemCursorOpener: CursorOpening {
    private let applicationOpener: ApplicationItemOpening
    private let openRequest = ApplicationItemOpenRequest(
        bundleIdentifier: "com.todesktop.230313mzl4w4u92",
        fallbackApplicationNames: ["Cursor.app"],
        applicationNotFoundError: .cursorApplicationNotFound
    )

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.applicationOpener = SystemApplicationItemOpener(
            workspace: workspace,
            fileManager: fileManager
        )
    }

    public func openCursor(at itemURLs: [URL]) throws {
        try applicationOpener.openItems(itemURLs, request: openRequest)
    }
}
