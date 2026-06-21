import AppKit
import Foundation

/// VS Code 打开能力独立成协议, 让执行器可以替换编辑器依赖.
public protocol CodeOpening: AnyObject {
    func openCode(at itemURLs: [URL]) throws
}

/// 系统 VS Code 打开器负责把文件和目录交给 Visual Studio Code 处理.
public final class SystemCodeOpener: CodeOpening {
    private let applicationOpener: ApplicationItemOpening
    private let openRequest = ApplicationItemOpenRequest(
        bundleIdentifier: "com.microsoft.VSCode",
        fallbackApplicationNames: ["Visual Studio Code.app"],
        applicationNotFoundError: .codeApplicationNotFound
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

    public func openCode(at itemURLs: [URL]) throws {
        try applicationOpener.openItems(itemURLs, request: openRequest)
    }
}
