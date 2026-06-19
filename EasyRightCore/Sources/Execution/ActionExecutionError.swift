import Foundation

/// 动作执行错误只描述可恢复场景, 便于后续映射到通知和日志.
public enum ActionExecutionError: Error, Equatable, Sendable {
    case emptySelection
    case unavailableAction(ActionIdentifier)
    case unsupportedAction(ActionIdentifier)
    case pasteboardWriteFailed
}
