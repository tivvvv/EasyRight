import Foundation

/// 动作执行器只负责调度已实现的轻量动作.
public final class ActionExecutor {
    public static let supportedActionIDs: Set<ActionIdentifier> = [
        .copyDirectoryPath,
        .copyFileName,
        .copyPath,
        .createFolder,
        .createTextFile,
        .openTerminalHere,
    ]

    private let fileCreator: FileCreating
    private let itemNamePrompter: ItemNamePrompting
    private let pasteboardWriter: PasteboardWriting
    private let terminalOpener: TerminalOpening

    public init(
        fileCreator: FileCreating = SystemFileCreator(),
        itemNamePrompter: ItemNamePrompting = SystemItemNamePrompter(),
        pasteboardWriter: PasteboardWriting = SystemPasteboardWriter(),
        terminalOpener: TerminalOpening = SystemTerminalOpener()
    ) {
        self.fileCreator = fileCreator
        self.itemNamePrompter = itemNamePrompter
        self.pasteboardWriter = pasteboardWriter
        self.terminalOpener = terminalOpener
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
        case .createFolder:
            return try createFolder(context: context)
        case .createTextFile:
            return try createTextFile(context: context)
        case .openTerminalHere:
            return try openTerminalHere(context: context)
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
        let selectedURL = try singleSelectedURL(context: context)
        let directoryURL = selectedURL.easyRightDirectoryURL
        let fileName = try normalizedItemName(
            itemNamePrompter.promptForItemName(
                title: "Create Text File",
                message: "Enter the new text file name.",
                defaultName: "Untitled.txt"
            )
        )
        let fileNameComponents = textFileNameComponents(from: fileName)
        let fileURL = fileCreator.availableFileURL(
            in: directoryURL,
            baseName: fileNameComponents.baseName,
            fileExtension: fileNameComponents.fileExtension
        )

        try fileCreator.createEmptyFile(at: fileURL)

        return ActionExecutionResult(message: "Created \(fileURL.lastPathComponent).")
    }

    private func createFolder(context: ActionExecutionContext) throws -> ActionExecutionResult {
        let selectedURL = try singleSelectedURL(context: context)
        let directoryURL = selectedURL.easyRightDirectoryURL
        let folderName = try normalizedItemName(
            itemNamePrompter.promptForItemName(
                title: "Create Folder",
                message: "Enter the new folder name.",
                defaultName: "Untitled Folder"
            )
        )
        let folderURL = fileCreator.availableDirectoryURL(
            in: directoryURL,
            baseName: folderName
        )

        try fileCreator.createDirectory(at: folderURL)

        return ActionExecutionResult(message: "Created \(folderURL.lastPathComponent).")
    }

    private func openTerminalHere(context: ActionExecutionContext) throws -> ActionExecutionResult {
        let directoryURLs = uniqueURLs(context.selection.urls.map(\.easyRightDirectoryURL))

        guard !directoryURLs.isEmpty else {
            throw ActionExecutionError.emptySelection
        }

        try terminalOpener.openTerminal(at: directoryURLs)

        let noun = directoryURLs.count == 1 ? "directory" : "directories"
        return ActionExecutionResult(message: "Opened \(directoryURLs.count) \(noun) in Terminal.")
    }

    private func normalizedItemName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains(":")
        else {
            throw ActionExecutionError.invalidItemName(rawName)
        }

        return name
    }

    private func textFileNameComponents(from name: String) -> (
        baseName: String,
        fileExtension: String
    ) {
        guard let dotIndex = name.lastIndex(of: "."),
              dotIndex != name.startIndex,
              dotIndex < name.index(before: name.endIndex)
        else {
            return (baseName: name, fileExtension: "txt")
        }

        return (
            baseName: String(name[..<dotIndex]),
            fileExtension: String(name[name.index(after: dotIndex)...])
        )
    }

    private func singleSelectedURL(context: ActionExecutionContext) throws -> URL {
        guard context.selection.urls.count == 1 else {
            throw ActionExecutionError.invalidSelectionCount(
                expected: 1,
                actual: context.selection.urls.count
            )
        }

        guard let selectedURL = context.selection.urls.first else {
            throw ActionExecutionError.emptySelection
        }

        return selectedURL
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

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()

        return urls.filter { url in
            seenPaths.insert(url.standardizedFileURL.path).inserted
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

    func availableDirectoryURL(
        in directoryURL: URL,
        baseName: String
    ) -> URL

    func createEmptyFile(at fileURL: URL) throws

    func createDirectory(at directoryURL: URL) throws
}

/// 系统文件创建器负责命名避让, 并安全写入文件和目录.
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
            let candidateURL = availableURL(
                in: directoryURL,
                baseName: baseName,
                fileExtension: fileExtension,
                index: index,
                isDirectory: false
            )

            guard fileManager.fileExists(atPath: candidateURL.path) else {
                return candidateURL
            }

            index += 1
        }
    }

    public func availableDirectoryURL(
        in directoryURL: URL,
        baseName: String
    ) -> URL {
        var index = 1

        while true {
            let candidateURL = availableURL(
                in: directoryURL,
                baseName: baseName,
                fileExtension: nil,
                index: index,
                isDirectory: true
            )

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

    public func createDirectory(at directoryURL: URL) throws {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: false
            )
        } catch {
            throw ActionExecutionError.directoryCreationFailed(directoryURL)
        }
    }

    private func availableURL(
        in directoryURL: URL,
        baseName: String,
        fileExtension: String?,
        index: Int,
        isDirectory: Bool
    ) -> URL {
        let fileName = index == 1 ? baseName : "\(baseName) \(index)"
        let candidateURL = directoryURL
            .appendingPathComponent(fileName, isDirectory: isDirectory)

        if let fileExtension {
            return candidateURL
                .appendingPathExtension(fileExtension)
        }

        return candidateURL
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
