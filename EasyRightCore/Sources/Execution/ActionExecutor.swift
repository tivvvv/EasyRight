import Foundation

/// 动作执行器只负责调度已实现的轻量动作.
public final class ActionExecutor {
    public static let supportedActionIDs: Set<ActionIdentifier> = [
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
        case .copyPath:
            return try copyPath(context: context)
        default:
            throw ActionExecutionError.unsupportedAction(action.id)
        }
    }

    private func copyPath(context: ActionExecutionContext) throws -> ActionExecutionResult {
        let paths = context.selection.urls.map(\.path)

        guard !paths.isEmpty else {
            throw ActionExecutionError.emptySelection
        }

        try pasteboardWriter.writeString(paths.joined(separator: "\n"))

        let noun = paths.count == 1 ? "path" : "paths"
        return ActionExecutionResult(message: "Copied \(paths.count) \(noun).")
    }
}
