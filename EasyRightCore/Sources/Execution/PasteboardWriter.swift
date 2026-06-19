import AppKit

/// 剪贴板写入能力独立成协议, 让执行器可以被单元测试替换依赖.
public protocol PasteboardWriting: AnyObject {
    func writeString(_ value: String) throws
}

/// 系统剪贴板写入器负责封装 AppKit 细节.
public final class SystemPasteboardWriter: PasteboardWriting {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func writeString(_ value: String) throws {
        pasteboard.clearContents()

        guard pasteboard.setString(value, forType: .string) else {
            throw ActionExecutionError.pasteboardWriteFailed
        }
    }
}
