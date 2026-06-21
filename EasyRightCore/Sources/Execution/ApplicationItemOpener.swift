import AppKit
import Foundation

/// App 打开请求集中描述应用定位信息和失败错误.
struct ApplicationItemOpenRequest {
    let bundleIdentifier: String
    let fallbackApplicationNames: [String]
    let applicationNotFoundError: ActionExecutionError
}

/// App 打开能力封装 NSWorkspace 细节, 让具体编辑器只声明自身配置.
protocol ApplicationItemOpening: AnyObject {
    func openItems(_ itemURLs: [URL], request: ApplicationItemOpenRequest) throws
}

/// 系统 App 打开器负责定位应用并把文件或目录交给该应用处理.
final class SystemApplicationItemOpener: ApplicationItemOpening {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func openItems(_ itemURLs: [URL], request: ApplicationItemOpenRequest) throws {
        guard let applicationURL = applicationURL(for: request) else {
            throw request.applicationNotFoundError
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        workspace.open(
            itemURLs,
            withApplicationAt: applicationURL,
            configuration: configuration,
            completionHandler: nil
        )
    }

    private func applicationURL(for request: ApplicationItemOpenRequest) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: request.bundleIdentifier)
            ?? fallbackApplicationURLs(for: request.fallbackApplicationNames)
                .first { fileManager.fileExists(atPath: $0.path) }
    }

    private func fallbackApplicationURLs(for applicationNames: [String]) -> [URL] {
        let applicationDirectoryURLs = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
        ]

        return applicationDirectoryURLs.flatMap { directoryURL in
            applicationNames.map { applicationName in
                directoryURL.appendingPathComponent(applicationName, isDirectory: true)
            }
        }
    }
}
