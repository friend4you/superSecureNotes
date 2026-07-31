import SecureCrypto
import XCTest

final class NotePayloadFileTests: XCTestCase {
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

    func testPayloadFileRoundtrip() throws {
        let payloadURL = temporaryDirectory.appendingPathComponent("payload")
        let encryptedPayload = Data(repeating: 0xAB, count: 64)

        try writeNotePayloadFile(encryptedPayload, to: payloadURL)
        let readPayload = try readNotePayloadFile(from: payloadURL)

        XCTAssertEqual(readPayload, encryptedPayload)
    }

    func testRejectEmptyPayloadValidation() {
        XCTAssertThrowsError(try validateNotePayloadFile(Data())) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidInput("Note payload file must not be empty.")
            )
        }
    }

    func testRejectEmptyPayloadWrite() throws {
        let payloadURL = temporaryDirectory.appendingPathComponent("payload")

        XCTAssertThrowsError(try writeNotePayloadFile(Data(), to: payloadURL)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidInput("Note payload file must not be empty.")
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: payloadURL.path))
    }

    func testRejectEmptyPayloadFileOnDisk() throws {
        let payloadURL = temporaryDirectory.appendingPathComponent("payload")
        try Data().write(to: payloadURL)

        XCTAssertThrowsError(try readNotePayloadFile(from: payloadURL)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidInput("Note payload file must not be empty.")
            )
        }
    }
}
