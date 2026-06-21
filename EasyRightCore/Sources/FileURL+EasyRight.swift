import Foundation

extension URL {
    var easyRightDirectoryPath: String {
        easyRightDirectoryURL.standardizedFileURL.path
    }

    var easyRightDirectoryURL: URL {
        easyRightIsDirectory ? self : deletingLastPathComponent()
    }

    var easyRightIsDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? hasDirectoryPath
    }
}
