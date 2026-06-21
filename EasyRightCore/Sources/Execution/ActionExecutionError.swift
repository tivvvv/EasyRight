import Foundation

/// 动作执行错误只描述可恢复场景, 便于后续映射到通知和日志.
public enum ActionExecutionError: Error, Equatable, Sendable {
    case codeApplicationNotFound
    case cursorApplicationNotFound
    case directoryCreationFailed(URL)
    case emptySelection
    case fileCreationFailed(URL)
    case invalidFileExtension(String)
    case invalidItemName(String)
    case invalidSelectionCount(expected: Int, actual: Int)
    case nameInputCancelled
    case terminalApplicationNotFound
    case unavailableAction(ActionIdentifier)
    case unsupportedAction(ActionIdentifier)
    case pasteboardWriteFailed
}

public extension ActionExecutionError {
    var shouldSuppressUserFeedback: Bool {
        switch self {
        case .nameInputCancelled:
            true
        default:
            false
        }
    }

    var userFeedbackMessage: String {
        switch self {
        case .codeApplicationNotFound:
            "VS Code could not be found."
        case .cursorApplicationNotFound:
            "Cursor could not be found."
        case .directoryCreationFailed:
            "Could not create the folder."
        case .emptySelection:
            "Select at least one item and try again."
        case .fileCreationFailed:
            "Could not create the file."
        case .invalidFileExtension:
            "Enter a valid file extension. Extensions cannot be empty or contain path separators."
        case .invalidItemName:
            "Enter a valid name. Names cannot be empty, '.', '..', or contain path separators."
        case let .invalidSelectionCount(expected, _):
            "Select exactly \(expected) \(expected == 1 ? "item" : "items") and try again."
        case .nameInputCancelled:
            "Action cancelled."
        case .terminalApplicationNotFound:
            "Terminal could not be found."
        case .unavailableAction:
            "This action is not available for the current selection."
        case .unsupportedAction:
            "This action is not supported yet."
        case .pasteboardWriteFailed:
            "Could not copy the value to the clipboard."
        }
    }
}

public extension Error {
    var easyRightShouldSuppressUserFeedback: Bool {
        if let actionError = self as? ActionExecutionError {
            return actionError.shouldSuppressUserFeedback
        }

        return false
    }

    var easyRightUserFeedbackMessage: String {
        if let actionError = self as? ActionExecutionError {
            return actionError.userFeedbackMessage
        }

        return "The action could not be completed."
    }
}
