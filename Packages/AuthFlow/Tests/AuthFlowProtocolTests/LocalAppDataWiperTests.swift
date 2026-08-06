import AuthFlowProtocol
import XCTest

final class FileSystemLocalAppDataWiperTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        super.tearDown()
    }

    func testWipeAllRemovesRootDirectoryAndContents() async throws {
        let vaultDirectory = temporaryDirectory.appendingPathComponent("vault", isDirectory: true)
        let notesDirectory = temporaryDirectory.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        try Data([0x01]).write(
            to: vaultDirectory.appendingPathComponent("vault-header.bin"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: notesDirectory.appendingPathComponent("notes.db"),
            options: .atomic
        )

        let wiper = FileSystemLocalAppDataWiper(rootURL: temporaryDirectory)
        try await wiper.wipeAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.path))
    }

    func testWipeAllIsNoOpWhenRootMissing() async throws {
        let missingRoot = temporaryDirectory.appendingPathComponent("missing", isDirectory: true)
        let wiper = FileSystemLocalAppDataWiper(rootURL: missingRoot)

        try await wiper.wipeAll()
    }
}
