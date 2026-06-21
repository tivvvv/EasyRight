import Foundation

/// Finder 当前选择的文件上下文, Core 层只保留可测试的纯数据.
public struct FileSelection: Hashable, Sendable {
    public let urls: [URL]

    public init(urls: [URL]) {
        self.urls = urls
    }

    public var isEmpty: Bool {
        urls.isEmpty
    }

    public var isSingleItem: Bool {
        urls.count == 1
    }

    public var isMultipleItems: Bool {
        urls.count > 1
    }

    public var containsDirectory: Bool {
        urls.contains { $0.easyRightIsDirectory }
    }

    public var containsFile: Bool {
        urls.contains { !$0.easyRightIsDirectory }
    }

    public var containsOnlyDirectories: Bool {
        !urls.isEmpty && urls.allSatisfy { $0.easyRightIsDirectory }
    }

    public var containsOnlyFiles: Bool {
        !urls.isEmpty && urls.allSatisfy { !$0.easyRightIsDirectory }
    }
}
