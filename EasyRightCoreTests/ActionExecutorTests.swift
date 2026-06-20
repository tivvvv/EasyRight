import XCTest
@testable import EasyRightCore

final class ActionExecutorTests: XCTestCase {
    func testCopyPathWritesSelectedPathsInOrder() throws {
        let pasteboardWriter = SpyPasteboardWriter()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: pasteboardWriter
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.txt")

        let result = try executor.execute(
            .copyPath,
            context: makeContext(urls: [firstURL, secondURL])
        )

        XCTAssertEqual(
            pasteboardWriter.writtenStrings,
            [firstURL.path + "\n" + secondURL.path]
        )
        XCTAssertEqual(result.message, "Copied 2 paths.")
    }

    func testCopyFileNameWritesSelectedFileNamesInOrder() throws {
        let pasteboardWriter = SpyPasteboardWriter()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: pasteboardWriter
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.md")

        let result = try executor.execute(
            .copyFileName,
            context: makeContext(urls: [firstURL, secondURL])
        )

        XCTAssertEqual(pasteboardWriter.writtenStrings, ["Alpha.txt\nBeta.md"])
        XCTAssertEqual(result.message, "Copied 2 file names.")
    }

    func testCopyDirectoryPathWritesUniqueDirectoryPaths() throws {
        let pasteboardWriter = SpyPasteboardWriter()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: pasteboardWriter
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.md")
        let thirdURL = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)
        let expectedValues = [
            firstURL.deletingLastPathComponent().standardizedFileURL.path,
            thirdURL.standardizedFileURL.path,
        ]

        let result = try executor.execute(
            .copyDirectoryPath,
            context: makeContext(urls: [firstURL, secondURL, thirdURL])
        )

        XCTAssertEqual(
            pasteboardWriter.writtenStrings,
            [expectedValues.joined(separator: "\n")]
        )
        XCTAssertEqual(result.message, "Copied 2 directory paths.")
    }

    func testCreateTextFileRequestsAvailableNameInSelectedFileDirectory() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Project Notes.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let itemNamePrompter = SpyItemNamePrompter(itemName: "Project Notes.txt")
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: itemNamePrompter,
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createTextFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.deletingLastPathComponent().standardizedFileURL.path]
        )
        XCTAssertEqual(
            itemNamePrompter.promptRequests,
            [
                ItemNamePromptRequest(
                    title: "Create Text File",
                    message: "Enter the new text file name.",
                    defaultName: "Untitled.txt"
                ),
            ]
        )
        XCTAssertEqual(fileCreator.requestedBaseNames, ["Project Notes"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Project Notes.txt.")
    }

    func testCreateTextFileAddsDefaultExtensionWhenPromptNameHasNoExtension() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Project Notes.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(itemName: "Project Notes"),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createTextFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(fileCreator.requestedBaseNames, ["Project Notes"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Project Notes.txt.")
    }

    func testCreateTextFileHandlesHiddenNameWithoutEmptyBaseName() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/.env.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(itemName: ".env"),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createTextFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(fileCreator.requestedBaseNames, [".env"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created .env.txt.")
    }

    func testCreateTextFileUsesSelectedDirectoryAsTargetDirectory() throws {
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let targetURL = selectedURL.appendingPathComponent("Project Notes.txt", isDirectory: false)
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(itemName: "Project Notes.txt"),
            pasteboardWriter: SpyPasteboardWriter()
        )

        _ = try executor.execute(
            .createTextFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.standardizedFileURL.path]
        )
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
    }

    func testCreateFolderRequestsAvailableNameInSelectedFileDirectory() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Reports")
        let fileCreator = SpyFileCreator(nextAvailableDirectoryURL: targetURL)
        let itemNamePrompter = SpyItemNamePrompter(itemName: "Reports")
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: itemNamePrompter,
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createFolder,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.deletingLastPathComponent().standardizedFileURL.path]
        )
        XCTAssertEqual(
            itemNamePrompter.promptRequests,
            [
                ItemNamePromptRequest(
                    title: "Create Folder",
                    message: "Enter the new folder name.",
                    defaultName: "Untitled Folder"
                ),
            ]
        )
        XCTAssertEqual(fileCreator.requestedBaseNames, ["Reports"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, [])
        XCTAssertEqual(fileCreator.createdDirectoryURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Reports.")
    }

    func testCreateFolderUsesSelectedDirectoryAsTargetDirectory() throws {
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let targetURL = selectedURL.appendingPathComponent(
            "Reports",
            isDirectory: true
        )
        let fileCreator = SpyFileCreator(nextAvailableDirectoryURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(itemName: "Reports"),
            pasteboardWriter: SpyPasteboardWriter()
        )

        _ = try executor.execute(
            .createFolder,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.standardizedFileURL.path]
        )
        XCTAssertEqual(fileCreator.createdDirectoryURLs, [targetURL])
    }

    func testCreateFolderRejectsInvalidPromptName() {
        let fileCreator = SpyFileCreator()
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(itemName: "bad/name"),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)

        XCTAssertThrowsError(
            try executor.execute(
                .createFolder,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .invalidItemName("bad/name")
            )
        }
        XCTAssertEqual(fileCreator.requestedDirectoryURLs, [])
        XCTAssertEqual(fileCreator.createdDirectoryURLs, [])
    }

    func testOpenTerminalHereOpensSelectedFileDirectory() throws {
        let terminalOpener = SpyTerminalOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            terminalOpener: terminalOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .openTerminalHere,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            terminalOpener.openedDirectoryURLBatches.map { batch in
                batch.map { $0.standardizedFileURL.path }
            },
            [[selectedURL.deletingLastPathComponent().standardizedFileURL.path]]
        )
        XCTAssertEqual(result.message, "Opened 1 directory in Terminal.")
    }

    func testOpenTerminalHereOpensSelectedDirectory() throws {
        let terminalOpener = SpyTerminalOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            terminalOpener: terminalOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)

        let result = try executor.execute(
            .openTerminalHere,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            terminalOpener.openedDirectoryURLBatches.map { batch in
                batch.map { $0.standardizedFileURL.path }
            },
            [[selectedURL.standardizedFileURL.path]]
        )
        XCTAssertEqual(result.message, "Opened 1 directory in Terminal.")
    }

    func testOpenTerminalHereOpensUniqueDirectories() throws {
        let terminalOpener = SpyTerminalOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            terminalOpener: terminalOpener
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.md")
        let thirdURL = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)
        let expectedPaths = [
            firstURL.deletingLastPathComponent().standardizedFileURL.path,
            thirdURL.standardizedFileURL.path,
        ]

        let result = try executor.execute(
            .openTerminalHere,
            context: makeContext(urls: [firstURL, secondURL, thirdURL])
        )

        XCTAssertEqual(
            terminalOpener.openedDirectoryURLBatches.map { batch in
                batch.map { $0.standardizedFileURL.path }
            },
            [expectedPaths]
        )
        XCTAssertEqual(result.message, "Opened 2 directories in Terminal.")
    }

    func testUnavailableActionThrowsBeforeWriting() {
        let pasteboardWriter = SpyPasteboardWriter()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: pasteboardWriter
        )

        XCTAssertThrowsError(
            try executor.execute(
                .createTextFile,
                context: makeContext(urls: [])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .unavailableAction(.createTextFile)
            )
        }
        XCTAssertEqual(pasteboardWriter.writtenStrings, [])
    }

    func testUnsupportedActionThrows() {
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents")

        XCTAssertFalse(executor.canExecute(.openWithCode))
        XCTAssertThrowsError(
            try executor.execute(
                .openWithCode,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .unsupportedAction(.openWithCode)
            )
        }
    }
}

final class SystemFileCreatorTests: XCTestCase {
    func testAvailableFileURLSkipsExistingNames() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        try Data().write(to: directoryURL.appendingPathComponent("Untitled.txt"))
        try Data().write(to: directoryURL.appendingPathComponent("Untitled 2.txt"))
        let fileCreator = SystemFileCreator(fileManager: fileManager)

        let fileURL = fileCreator.availableFileURL(
            in: directoryURL,
            baseName: "Untitled",
            fileExtension: "txt"
        )

        XCTAssertEqual(fileURL.lastPathComponent, "Untitled 3.txt")
    }

    func testAvailableDirectoryURLSkipsExistingNames() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        try fileManager.createDirectory(
            at: directoryURL.appendingPathComponent("Untitled Folder", isDirectory: true),
            withIntermediateDirectories: false
        )
        try fileManager.createDirectory(
            at: directoryURL.appendingPathComponent("Untitled Folder 2", isDirectory: true),
            withIntermediateDirectories: false
        )
        let fileCreator = SystemFileCreator(fileManager: fileManager)

        let folderURL = fileCreator.availableDirectoryURL(
            in: directoryURL,
            baseName: "Untitled Folder"
        )

        XCTAssertEqual(folderURL.lastPathComponent, "Untitled Folder 3")
    }

    func testCreateEmptyFileCreatesFileWithoutOverwriting() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        let fileURL = directoryURL.appendingPathComponent("Untitled.txt")
        let fileCreator = SystemFileCreator(fileManager: fileManager)

        try fileCreator.createEmptyFile(at: fileURL)

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        XCTAssertEqual((attributes[.size] as? NSNumber)?.intValue, 0)
        XCTAssertThrowsError(try fileCreator.createEmptyFile(at: fileURL)) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .fileCreationFailed(fileURL)
            )
        }
    }

    func testCreateDirectoryCreatesDirectoryWithoutOverwriting() throws {
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        let folderURL = directoryURL.appendingPathComponent("Untitled Folder")
        let fileCreator = SystemFileCreator(fileManager: fileManager)

        try fileCreator.createDirectory(at: folderURL)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertThrowsError(try fileCreator.createDirectory(at: folderURL)) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .directoryCreationFailed(folderURL)
            )
        }
    }
}

final class ActionRegistryTests: XCTestCase {
    func testStandardRegistryIncludesCreateActionsForSingleSelection() {
        let registry = ActionRegistry.standard
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let actionIDs = registry
            .availableActions(for: FileSelection(urls: [selectedURL]))
            .map(\.id)

        XCTAssertTrue(actionIDs.contains(.copyPath))
        XCTAssertTrue(actionIDs.contains(.copyFileName))
        XCTAssertTrue(actionIDs.contains(.copyDirectoryPath))
        XCTAssertTrue(actionIDs.contains(.createTextFile))
        XCTAssertTrue(actionIDs.contains(.createFolder))
        XCTAssertTrue(actionIDs.contains(.openTerminalHere))
    }

    func testStandardRegistryHidesCreateActionsForMultipleSelection() {
        let registry = ActionRegistry.standard
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Alpha.txt")
        let secondURL = URL(fileURLWithPath: "/Users/example/Documents/Beta.md")

        let actionIDs = registry
            .availableActions(for: FileSelection(urls: [firstURL, secondURL]))
            .map(\.id)

        XCTAssertTrue(actionIDs.contains(.copyPath))
        XCTAssertTrue(actionIDs.contains(.copyFileName))
        XCTAssertTrue(actionIDs.contains(.copyDirectoryPath))
        XCTAssertFalse(actionIDs.contains(.createTextFile))
        XCTAssertFalse(actionIDs.contains(.createFolder))
        XCTAssertTrue(actionIDs.contains(.openTerminalHere))
    }
}

private final class SpyPasteboardWriter: PasteboardWriting {
    private(set) var writtenStrings: [String] = []
    var errorToThrow: Error?

    func writeString(_ value: String) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        writtenStrings.append(value)
    }
}

private struct ItemNamePromptRequest: Equatable {
    let title: String
    let message: String
    let defaultName: String
}

private final class SpyItemNamePrompter: ItemNamePrompting {
    private(set) var promptRequests: [ItemNamePromptRequest] = []
    var itemName: String
    var errorToThrow: Error?

    init(itemName: String = "Untitled") {
        self.itemName = itemName
    }

    func promptForItemName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        promptRequests.append(
            ItemNamePromptRequest(
                title: title,
                message: message,
                defaultName: defaultName
            )
        )

        if let errorToThrow {
            throw errorToThrow
        }

        return itemName
    }
}

private final class SpyFileCreator: FileCreating {
    private(set) var requestedDirectoryURLs: [URL] = []
    private(set) var requestedBaseNames: [String] = []
    private(set) var requestedFileExtensions: [String] = []
    private(set) var createdDirectoryURLs: [URL] = []
    private(set) var createdFileURLs: [URL] = []
    var nextAvailableDirectoryURL: URL
    var nextAvailableFileURL: URL
    var errorToThrow: Error?

    init(
        nextAvailableDirectoryURL: URL = URL(fileURLWithPath: "/Users/example/Untitled Folder"),
        nextAvailableFileURL: URL = URL(fileURLWithPath: "/Users/example/Untitled.txt")
    ) {
        self.nextAvailableDirectoryURL = nextAvailableDirectoryURL
        self.nextAvailableFileURL = nextAvailableFileURL
    }

    func availableFileURL(
        in directoryURL: URL,
        baseName: String,
        fileExtension: String
    ) -> URL {
        requestedDirectoryURLs.append(directoryURL)
        requestedBaseNames.append(baseName)
        requestedFileExtensions.append(fileExtension)
        return nextAvailableFileURL
    }

    func availableDirectoryURL(
        in directoryURL: URL,
        baseName: String
    ) -> URL {
        requestedDirectoryURLs.append(directoryURL)
        requestedBaseNames.append(baseName)
        return nextAvailableDirectoryURL
    }

    func createEmptyFile(at fileURL: URL) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        createdFileURLs.append(fileURL)
    }

    func createDirectory(at directoryURL: URL) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        createdDirectoryURLs.append(directoryURL)
    }
}

private final class SpyTerminalOpener: TerminalOpening {
    private(set) var openedDirectoryURLBatches: [[URL]] = []
    var errorToThrow: Error?

    func openTerminal(at directoryURLs: [URL]) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        openedDirectoryURLBatches.append(directoryURLs)
    }
}

private func makeContext(urls: [URL]) -> ActionExecutionContext {
    ActionExecutionContext(selection: FileSelection(urls: urls))
}

private func makeTemporaryDirectory(fileManager: FileManager) throws -> URL {
    let directoryURL = fileManager.temporaryDirectory
        .appendingPathComponent("EasyRightCoreTests-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    return directoryURL
}
