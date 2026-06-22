import Foundation

/// 文件内容读取能力独立成协议, 让复制内容动作可以替换文件系统依赖.
public protocol FileContentReading: AnyObject {
    func stringContents(of fileURL: URL) throws -> String
}

/// 系统文件内容读取器只读取 UTF-8 文本, 避免把二进制内容误写到剪贴板.
public final class SystemFileContentReader: FileContentReading {
    public init() {}

    public func stringContents(of fileURL: URL) throws -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ActionExecutionError.fileContentReadFailed(fileURL)
        }
    }
}
