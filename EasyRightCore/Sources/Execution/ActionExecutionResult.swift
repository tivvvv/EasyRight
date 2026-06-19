import Foundation

/// 动作执行结果保留人类可读消息, 供日志和后续通知复用.
public struct ActionExecutionResult: Hashable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
