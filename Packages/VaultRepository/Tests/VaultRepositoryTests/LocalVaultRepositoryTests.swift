import VaultRepositoryProtocol
import XCTest

@testable import VaultRepository

final class LocalVaultRepositoryTests: XCTestCase {
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

    func testWriteThenReadHeaderRoundtrip() async throws {
        let repository = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)
        let header = Data([0x01, 0x02, 0x03])

        try await repository.writeHeader(header)
        let readHeader = try await repository.readHeader()

        XCTAssertEqual(readHeader, header)
    }

    func testReadHeaderWhenFileMissingThrowsHeaderNotFound() async {
        let repository = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)

        do {
            _ = try await repository.readHeader()
            XCTFail("Expected headerNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .headerNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHeaderSurvivesNewRepositoryInstance() async throws {
        let header = Data([0x0A, 0x0B, 0x0C])
        let writer = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)
        try await writer.writeHeader(header)

        let reader = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)
        let readHeader = try await reader.readHeader()

        XCTAssertEqual(readHeader, header)
    }

    func testAtomicHeaderWrite() async throws {
        let repository = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)
        let firstHeader = Data([0x01, 0x02, 0x03])
        let secondHeader = Data([0x04, 0x05, 0x06, 0x07])

        try await repository.writeHeader(firstHeader)
        try await repository.writeHeader(secondHeader)
        let readHeader = try await repository.readHeader()

        XCTAssertEqual(readHeader, secondHeader)
    }

    func testVaultDirectoryExcludedFromBackup() async throws {
        let repository = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)
        try await repository.writeHeader(Data([0x01]))

        let values = try temporaryDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
