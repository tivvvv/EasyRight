import AppKit
import Foundation

/// 终端打开能力独立成协议, 让执行器可以替换系统应用依赖.
public protocol TerminalOpening: AnyObject {
    func openTerminal(at directoryURLs: [URL]) throws
}

/// 系统终端打开器负责把目录交给 Terminal.app 处理.
public final class SystemTerminalOpener: TerminalOpening {
    private let workspace: NSWorkspace
    private let terminalBundleIdentifier = "com.apple.Terminal"

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func openTerminal(at directoryURLs: [URL]) throws {
        guard let terminalURL = workspace.urlForApplication(
            withBundleIdentifier: terminalBundleIdentifier
        ) else {
            throw ActionExecutionError.terminalApplicationNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        for directoryURL in directoryURLs {
            workspace.open(
                [directoryURL],
                withApplicationAt: terminalURL,
                configuration: configuration,
                completionHandler: nil
            )
        }
    }
}
