import Foundation

/// 动作执行上下文集中保存一次右键触发时的输入数据.
public struct ActionExecutionContext: Hashable, Sendable {
    public let selection: FileSelection

    public init(selection: FileSelection) {
        self.selection = selection
    }
}
