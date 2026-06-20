import Foundation

/// 动作执行器只负责调度已实现的轻量动作.
public final class ActionExecutor {
    public static let supportedActionIDs: Set<ActionIdentifier> = [
        .copyDirectoryPath,
        .copyFileName,
        .copyPath,
        .createTextFile,
    ]

    private let fileCreator: FileCreating
    private let pasteboardWriter: PasteboardWriting

    public init(
        fileCreator: FileCreating = SystemFileCreator(),
        pasteboardWriter: PasteboardWriting = SystemPasteboardWriter()
    ) {
        self.fileCreator = fileCreator
        self.pasteboardWriter = pasteboardWriter
    }

    public func canExecute(_ action: RightClickActionDescriptor) -> Bool {
        Self.supportedActionIDs.contains(action.id)
    }

    @discardableResult
    public func execute(
        _ action: RightClickActionDescriptor,
        context: ActionExecutionContext
    ) throws -> ActionExecutionResult {
        guard action.isAvailable(for: context.selection) else {
            throw ActionExecutionError.unavailableAction(action.id)
        }

        switch action.id {
        case .copyDirectoryPath:
            return try copyDirectoryPath(context: context)
        case .copyFileName:
            return try copyFileName(context: context)
        case .copyPath:
            return try copyPath(context: context)
        case .createTextFile:
            return try createTextFile(context: context)
        default:
            throw ActionExecutionError.unsupportedAction(action.id)
        }
    }

    private func copyPath(context: ActionExecutionContext) throws -> ActionExecutionResult {
        try copyValues(
            context.selection.urls.map(\.path),
            singularName: "path",
            pluralName: "paths"
        )
    }

    private func copyDirectoryPath(context: ActionExecutionContext) throws -> ActionExecutionResult {
        try copyValues(
            uniqueValues(context.selection.urls.map(\.easyRightDirectoryPath)),
            singularName: "directory path",
            pluralName: "directory paths"
        )
    }

    private func copyFileName(context: ActionExecutionContext) throws -> ActionExecutionResult {
        try copyValues(
            context.selection.urls.map(\.lastPathComponent),
            singularName: "file name",
            pluralName: "file names"
        )
    }

    private func createTextFile(context: ActionExecutionContext) throws -> ActionExecutionResult {
        guard context.selection.urls.count == 1 else {
            throw ActionExecutionError.invalidSelectionCount(
                expected: 1,
                actual: context.selection.urls.count
            )
        }

        guard let selectedURL = context.selection.urls.first else {
            throw ActionExecutionError.emptySelection
        }

        let directoryURL = selectedURL.easyRightDirectoryURL
        let fileURL = fileCreator.availableFileURL(
            in: directoryURL,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        try fileCreator.createEmptyFile(at: fileURL)

        return ActionExecutionResult(message: "Created \(fileURL.lastPathComponent).")
    }

    private func copyValues(
        _ values: [String],
        singularName: String,
        pluralName: String
    ) throws -> ActionExecutionResult {
        let copyableValues = values.filter { !$0.isEmpty }

        guard !copyableValues.isEmpty else {
            throw ActionExecutionError.emptySelection
        }

        try pasteboardWriter.writeString(copyableValues.joined(separator: "\n"))

        let noun = copyableValues.count == 1 ? singularName : pluralName
        return ActionExecutionResult(message: "Copied \(copyableValues.count) \(noun).")
    }

    private func uniqueValues(_ values: [String]) -> [String] {
        var seenValues = Set<String>()

        return values.filter { value in
            seenValues.insert(value).inserted
        }
    }
}

/// 文件创建能力独立成协议, 让执行器可以替换文件系统依赖.
public protocol FileCreating: AnyObject {
    func availableFileURL(
        in directoryURL: URL,
        baseName: String,
        fileExtension: String
    ) -> URL

    func createEmptyFile(at fileURL: URL) throws
}

/// 系统文件创建器负责命名避让和安全写入空文件.
public final class SystemFileCreator: FileCreating {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func availableFileURL(
        in directoryURL: URL,
        baseName: String,
        fileExtension: String
    ) -> URL {
        var index = 1

        while true {
            let fileName = index == 1 ? baseName : "\(baseName) \(index)"
            let candidateURL = directoryURL
                .appendingPathComponent(fileName, isDirectory: false)
                .appendingPathExtension(fileExtension)

            guard fileManager.fileExists(atPath: candidateURL.path) else {
                return candidateURL
            }

            index += 1
        }
    }

    public func createEmptyFile(at fileURL: URL) throws {
        do {
            try Data().write(to: fileURL, options: .withoutOverwriting)
        } catch {
            throw ActionExecutionError.fileCreationFailed(fileURL)
        }
    }
}

private extension URL {
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
