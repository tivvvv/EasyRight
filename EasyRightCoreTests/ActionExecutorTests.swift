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
        let targetURL = URL(fileURLWithPath: "/Users/example/Documents/Untitled.txt")
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
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
        XCTAssertEqual(fileCreator.requestedBaseNames, ["Untitled"])
        XCTAssertEqual(fileCreator.requestedFileExtensions, ["txt"])
        XCTAssertEqual(fileCreator.createdFileURLs, [targetURL])
        XCTAssertEqual(result.message, "Created Untitled.txt.")
    }

    func testCreateTextFileUsesSelectedDirectoryAsTargetDirectory() throws {
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let targetURL = selectedURL.appendingPathComponent("Untitled.txt", isDirectory: false)
        let fileCreator = SpyFileCreator(nextAvailableFileURL: targetURL)
        let executor = ActionExecutor(
            fileCreator: fileCreator,
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

        XCTAssertFalse(executor.canExecute(.openTerminalHere))
        XCTAssertThrowsError(
            try executor.execute(
                .openTerminalHere,
                context: makeContext(urls: [selectedURL])
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .unsupportedAction(.openTerminalHere)
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
}

final class ActionRegistryTests: XCTestCase {
    func testStandardRegistryIncludesCreateTextFileForSingleSelection() {
        let registry = ActionRegistry.standard
        let selectedURL = URL(fileURLWithPath: "/Users/example/Documents/Source.md")

        let actionIDs = registry
            .availableActions(for: FileSelection(urls: [selectedURL]))
            .map(\.id)

        XCTAssertTrue(actionIDs.contains(.copyPath))
        XCTAssertTrue(actionIDs.contains(.copyFileName))
        XCTAssertTrue(actionIDs.contains(.copyDirectoryPath))
        XCTAssertTrue(actionIDs.contains(.createTextFile))
    }

    func testStandardRegistryHidesCreateTextFileForMultipleSelection() {
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

private final class SpyFileCreator: FileCreating {
    private(set) var requestedDirectoryURLs: [URL] = []
    private(set) var requestedBaseNames: [String] = []
    private(set) var requestedFileExtensions: [String] = []
    private(set) var createdFileURLs: [URL] = []
    var nextAvailableFileURL: URL
    var errorToThrow: Error?

    init(nextAvailableFileURL: URL = URL(fileURLWithPath: "/Users/example/Untitled.txt")) {
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

    func createEmptyFile(at fileURL: URL) throws {
        if let errorToThrow {
            throw errorToThrow
        }

        createdFileURLs.append(fileURL)
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
