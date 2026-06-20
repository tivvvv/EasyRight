import Foundation

/// 动作执行器只负责调度已实现的轻量动作.
public final class ActionExecutor {
    public static let supportedActionIDs: Set<ActionIdentifier> = [
        .copyDirectoryPath,
        .copyFileName,
        .copyPath,
    ]

    private let pasteboardWriter: PasteboardWriting

    public init(pasteboardWriter: PasteboardWriting = SystemPasteboardWriter()) {
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

private extension URL {
    var easyRightDirectoryPath: String {
        let directoryURL = easyRightIsDirectory ? self : deletingLastPathComponent()
        return directoryURL.standardizedFileURL.path
    }

    var easyRightIsDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? hasDirectoryPath
    }
}
