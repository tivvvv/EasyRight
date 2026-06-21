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

    func testCreateFileRequestsAvailableNameInSelectedFileDirectory() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Project Notes.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let itemNamePrompter = SpyItemNamePrompter(
            fileBaseName: "Project Notes",
            fileExtension: "txt"
        )
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: itemNamePrompter,
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.deletingLastPathComponent().standardizedFileURL.path]
        )
        XCTAssertEqual(
            itemNamePrompter.fileNamePromptRequests,
            [
                FileNamePromptRequest(
                    title: "Create File",
                    message: "Enter the new file name and extension.",
                    defaultBaseName: "Untitled",
                    defaultFileExtension: "txt"
                ),
            ]
        )
        XCTAssertEqual(fileCreator.requestedBaseNames, ["Project Notes"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Project Notes.txt.")
    }

    func testCreateFileUsesDefaultExtensionFromPrompt() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Project Notes.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(fileBaseName: "Project Notes"),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(fileCreator.requestedBaseNames, ["Project Notes"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Project Notes.txt.")
    }

    func testCreateFileSupportsCustomExtension() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Project Notes.md")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(
                fileBaseName: "Project Notes",
                fileExtension: ".md"
            ),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(fileCreator.requestedBaseNames, ["Project Notes"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["md"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Project Notes.md.")
    }

    func testCreateFileHandlesHiddenNameWithoutEmptyBaseName() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/.env.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(fileBaseName: ".env"),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .createFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(fileCreator.requestedBaseNames, [".env"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created .env.txt.")
    }

    func testCreateFileUsesSelectedDirectoryAsTargetDirectory() throws {
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let targetURL = selectedURL.appendingPathComponent("Project Notes.txt", isDirectory: false)
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(fileBaseName: "Project Notes"),
            pasteboardWriter: SpyPasteboardWriter()
        )

        _ = try executor.execute(
            .createFile,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(
            fileCreator.requestedDirectoryURLs.map { $0.standardizedFileURL.path },
            [selectedURL.standardizedFileURL.path]
        )
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
    }

    func testCreateFileRejectsInvalidFileExtension() {
        let fileCreator = SpyFileCreator()
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(
                fileBaseName: "Project Notes",
                fileExtension: "bad/name"
            ),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)

        XCTAssertThrowsError(
            try executor.execute(
                .createFile,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .invalidFileExtension("bad/name")
            )
        }
        XCTAssertEqual(fileCreator.requestedDirectoryURLs, [])
        XCTAssertEqual(fileCreator.createdFileURLs, [])
    }

    func testCreateFileRejectsEmptyFileExtensionPart() {
        let fileCreator = SpyFileCreator()
        let executor = ActionExecutor(
            fileCreator: fileCreator,
            itemNamePrompter: SpyItemNamePrompter(
                fileBaseName: "Archive",
                fileExtension: "tar..gz"
            ),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)

        XCTAssertThrowsError(
            try executor.execute(
                .createFile,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .invalidFileExtension("tar..gz")
            )
        }
        XCTAssertEqual(fileCreator.requestedDirectoryURLs, [])
        XCTAssertEqual(fileCreator.createdFileURLs, [])
    }

    func testCreateFolderRequestsAvailableNameInSelectedFileDirectory() throws {
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Reports")
        let fileCreator = SpyFileCreator(nextAvailableDirectoryURL: targetURL)
        let itemNamePrompter = SpyItemNamePrompter(folderName: "Reports")
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
            itemNamePrompter.folderNamePromptRequests,
            [
                FolderNamePromptRequest(
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
            itemNamePrompter: SpyItemNamePrompter(folderName: "Reports"),
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
            itemNamePrompter: SpyItemNamePrompter(folderName: "bad/name"),
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

    func testOpenWithTerminalOpensSelectedFileDirectory() throws {
        let terminalOpener = SpyTerminalOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            terminalOpener: terminalOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .openWithTerminal,
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

    func testOpenWithTerminalOpensSelectedDirectory() throws {
        let terminalOpener = SpyTerminalOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            terminalOpener: terminalOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)

        let result = try executor.execute(
            .openWithTerminal,
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

    func testOpenWithTerminalOpensUniqueDirectories() throws {
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
            .openWithTerminal,
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

    func testOpenWithCursorOpensSelectedItem() throws {
        let cursorOpener = SpyCursorOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            cursorOpener: cursorOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .openWithCursor,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(cursorOpener.openedItemURLBatches, [[selectedURL]])
        XCTAssertEqual(result.message, "Opened 1 item in Cursor.")
    }

    func testOpenWithCursorOpensSelectedItems() throws {
        let cursorOpener = SpyCursorOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            cursorOpener: cursorOpener
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")
        let secondURL = URL(fileURLWithPath: "/Users/example/Project", isDirectory: true)

        let result = try executor.execute(
            .openWithCursor,
            context: makeContext(urls: [firstURL, secondURL])
        )

        XCTAssertEqual(cursorOpener.openedItemURLBatches, [[firstURL, secondURL]])
        XCTAssertEqual(result.message, "Opened 2 items in Cursor.")
    }

    func testOpenWithCursorThrowsWhenCursorIsUnavailable() {
        let cursorOpener = SpyCursorOpener()
        cursorOpener.errorToThrow = ActionExecutionError.cursorApplicationNotFound
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            cursorOpener: cursorOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        XCTAssertThrowsError(
            try executor.execute(
                .openWithCursor,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .cursorApplicationNotFound
            )
        }
        XCTAssertEqual(cursorOpener.openedItemURLBatches, [])
    }

    func testOpenWithCodeOpensSelectedItem() throws {
        let codeOpener = SpyCodeOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            codeOpener: codeOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let result = try executor.execute(
            .openWithCode,
            context: makeContext(urls: [selectedURL])
        )

        XCTAssertEqual(codeOpener.openedItemURLBatches, [[selectedURL]])
        XCTAssertEqual(result.message, "Opened 1 item in VS Code.")
    }

    func testOpenWithCodeOpensSelectedItems() throws {
        let codeOpener = SpyCodeOpener()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            codeOpener: codeOpener
        )
        let firstURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")
        let secondURL = URL(fileURLWithPath: "/Users/example/Project", isDirectory: true)

        let result = try executor.execute(
            .openWithCode,
            context: makeContext(urls: [firstURL, secondURL])
        )

        XCTAssertEqual(codeOpener.openedItemURLBatches, [[firstURL, secondURL]])
        XCTAssertEqual(result.message, "Opened 2 items in VS Code.")
    }

    func testOpenWithCodeThrowsWhenCodeIsUnavailable() {
        let codeOpener = SpyCodeOpener()
        codeOpener.errorToThrow = ActionExecutionError.codeApplicationNotFound
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter(),
            codeOpener: codeOpener
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        XCTAssertThrowsError(
            try executor.execute(
                .openWithCode,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .codeApplicationNotFound
            )
        }
        XCTAssertEqual(codeOpener.openedItemURLBatches, [])
    }

    func testUnavailableActionThrowsBeforeWriting() {
        let pasteboardWriter = SpyPasteboardWriter()
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: pasteboardWriter
        )

        XCTAssertThrowsError(
            try executor.execute(
                .createFile,
                context: makeContext(urls: [])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .unavailableAction(.createFile)
            )
        }
        XCTAssertEqual(pasteboardWriter.writtenStrings, [])
    }

    func testUnsupportedActionThrows() {
        let executor = ActionExecutor(
            fileCreator: SpyFileCreator(),
            pasteboardWriter: SpyPasteboardWriter()
        )
        let unsupportedAction = RightClickActionDescriptor(
            id: ActionIdentifier(rawValue: "unsupported_action"),
            title: "Unsupported Action",
            systemImageName: "questionmark",
            selectionRule: .nonEmptySelection
        )
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents")

        XCTAssertFalse(executor.canExecute(unsupportedAction))
        XCTAssertThrowsError(
            try executor.execute(
                unsupportedAction,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .unsupportedAction(unsupportedAction.id)
            )
        }
    }
}

final class ActionExecutionFeedbackTests: XCTestCase {
    func testNameInputCancelledSuppressesUserFeedback() {
        let error = ActionExecutionError.nameInputCancelled

        XCTAssertTrue(error.shouldSuppressUserFeedback)
        XCTAssertTrue(error.easyRightShouldSuppressUserFeedback)
        XCTAssertEqual(error.userFeedbackMessage, "Action cancelled.")
    }

    func testInvalidItemNameHasUserFeedbackMessage() {
        let error = ActionExecutionError.invalidItemName("bad/name")

        XCTAssertFalse(error.shouldSuppressUserFeedback)
        XCTAssertEqual(
            error.userFeedbackMessage,
            "Enter a valid name. Names cannot be empty, '.', '..', or contain path separators."
        )
    }

    func testInvalidFileExtensionHasUserFeedbackMessage() {
        let error = ActionExecutionError.invalidFileExtension("bad/name")

        XCTAssertFalse(error.shouldSuppressUserFeedback)
        XCTAssertEqual(
            error.userFeedbackMessage,
            "Enter a valid file extension. Extensions cannot be empty or contain path separators."
        )
    }

    func testCodeApplicationNotFoundHasUserFeedbackMessage() {
        let error = ActionExecutionError.codeApplicationNotFound

        XCTAssertFalse(error.shouldSuppressUserFeedback)
        XCTAssertEqual(error.userFeedbackMessage, "VS Code could not be found.")
    }

    func testCursorApplicationNotFoundHasUserFeedbackMessage() {
        let error = ActionExecutionError.cursorApplicationNotFound

        XCTAssertFalse(error.shouldSuppressUserFeedback)
        XCTAssertEqual(error.userFeedbackMessage, "Cursor could not be found.")
    }

    func testInvalidSelectionCountPluralizesUserFeedbackMessage() {
        let singularError = ActionExecutionError.invalidSelectionCount(expected: 1, actual: 0)
        let pluralError = ActionExecutionError.invalidSelectionCount(expected: 2, actual: 1)

        XCTAssertEqual(
            singularError.userFeedbackMessage,
            "Select exactly 1 item and try again."
        )
        XCTAssertEqual(
            pluralError.userFeedbackMessage,
            "Select exactly 2 items and try again."
        )
    }

    func testUnknownErrorUsesFallbackUserFeedbackMessage() {
        let error = NSError(domain: "EasyRightTests", code: 1)

        XCTAssertFalse(error.easyRightShouldSuppressUserFeedback)
        XCTAssertEqual(
            error.easyRightUserFeedbackMessage,
            "The action could not be completed."
        )
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
        XCTAssertTrue(actionIDs.contains(.createFile))
        XCTAssertTrue(actionIDs.contains(.createFolder))
        XCTAssertTrue(actionIDs.contains(.openWithTerminal))
        XCTAssertTrue(actionIDs.contains(.openWithCursor))
        XCTAssertTrue(actionIDs.contains(.openWithCode))
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
        XCTAssertFalse(actionIDs.contains(.createFile))
        XCTAssertFalse(actionIDs.contains(.createFolder))
        XCTAssertTrue(actionIDs.contains(.openWithTerminal))
        XCTAssertTrue(actionIDs.contains(.openWithCursor))
        XCTAssertTrue(actionIDs.contains(.openWithCode))
    }

    func testOpenWithTerminalKeepsExistingIdentifier() {
        XCTAssertEqual(ActionIdentifier.openWithTerminal.rawValue, "open_terminal_here")
        XCTAssertEqual(ActionIdentifier.openTerminalHere, .openWithTerminal)
        XCTAssertEqual(RightClickActionDescriptor.openTerminalHere, .openWithTerminal)
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

private struct FileNamePromptRequest: Equatable {
    let title: String
    let message: String
    let defaultBaseName: String
    let defaultFileExtension: String
}

private struct FolderNamePromptRequest: Equatable {
    let title: String
    let message: String
    let defaultName: String
}

private final class SpyItemNamePrompter: ItemNamePrompting {
    private(set) var fileNamePromptRequests: [FileNamePromptRequest] = []
    private(set) var folderNamePromptRequests: [FolderNamePromptRequest] = []
    var fileName: FileNamePromptResult
    var folderName: String
    var errorToThrow: Error?

    init(
        fileBaseName: String = "Untitled",
        fileExtension: String = "txt",
        folderName: String = "Untitled Folder"
    ) {
        self.fileName = FileNamePromptResult(
            baseName: fileBaseName,
            fileExtension: fileExtension
        )
        self.folderName = folderName
    }

    func promptForFileName(
        title: String,
        message: String,
        defaultBaseName: String,
        defaultFileExtension: String
    ) throws -> FileNamePromptResult {
        fileNamePromptRequests.append(
            FileNamePromptRequest(
                title: title,
                message: message,
                defaultBaseName: defaultBaseName,
                defaultFileExtension: defaultFileExtension
            )
        )

        if let errorToThrow {
            throw errorToThrow
        }

        return fileName
    }

    func promptForFolderName(
        title: String,
        message: String,
        defaultName: String
    ) throws -> String {
        folderNamePromptRequests.append(
            FolderNamePromptRequest(
                title: title,
                message: message,
                defaultName: defaultName
            )
        )

        if let errorToThrow {
            throw errorToThrow
        }

        return folderName
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

private final class SpyCursorOpener: CursorOpening {
    private(set) var openedItemURLBatches: [[URL]] = []
    var errorToThrow: Error?

    func openCursor(at itemURLs: [URL]) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        openedItemURLBatches.append(itemURLs)
    }
}

private final class SpyCodeOpener: CodeOpening {
    private(set) var openedItemURLBatches: [[URL]] = []
    var errorToThrow: Error?

    func openCode(at itemURLs: [URL]) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        openedItemURLBatches.append(itemURLs)
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
