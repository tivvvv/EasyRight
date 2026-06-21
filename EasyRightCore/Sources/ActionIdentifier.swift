import Foundation

/// 动作标识使用稳定字符串, 方便后续持久化配置和跨进程传递.
public struct ActionIdentifier: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ActionIdentifier {
    static let copyPath = ActionIdentifier(rawValue: "copy_path")
    static let copyFileName = ActionIdentifier(rawValue: "copy_file_name")
    static let copyDirectoryPath = ActionIdentifier(rawValue: "copy_directory_path")
    static let createFile = ActionIdentifier(rawValue: "create_file")
    static let createFolder = ActionIdentifier(rawValue: "create_folder")
    static let openTerminalHere = ActionIdentifier(rawValue: "open_terminal_here")
    static let openWithCursor = ActionIdentifier(rawValue: "open_with_cursor")
    static let openWithCode = ActionIdentifier(rawValue: "open_with_code")
}
