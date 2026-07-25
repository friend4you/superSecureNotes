import VaultRepositoryProtocol
import XCTest

@testable import superSecureNotes

final class FileVaultRepositoryTests: XCTestCase {
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
        let repository = FileVaultRepository(directoryURL: temporaryDirectory)
        let header = Data([0x01, 0x02, 0x03])

        try await repository.writeHeader(header)
        let readHeader = try await repository.readHeader()

        XCTAssertEqual(readHeader, header)
    }

    func testReadHeaderWhenFileMissingThrowsHeaderNotFound() async {
        let repository = FileVaultRepository(directoryURL: temporaryDirectory)

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
        let writer = FileVaultRepository(directoryURL: temporaryDirectory)
        try await writer.writeHeader(header)

        let reader = FileVaultRepository(directoryURL: temporaryDirectory)
        let readHeader = try await reader.readHeader()

        XCTAssertEqual(readHeader, header)
    }
}
