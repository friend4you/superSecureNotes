import XCTest

@testable import SecureCrypto

final class LocalNoteBodyTests: XCTestCase {
    func testAssembleAndParseRoundtrip() throws {
        let metadata = makeSampleMetadata()
        let encryptedPayload = Data(repeating: 0xCD, count: 256)

        let localBody = try assembleLocalNoteBody(
            metadata: metadata,
            encryptedPayload: encryptedPayload
        )
        let sections = try parseLocalNoteBody(localBody)

        XCTAssertEqual(sections.metadata, metadata)
        XCTAssertEqual(sections.encryptedPayload, encryptedPayload)
    }

    func testRejectsInvalidMagic() {
        var data = Data(repeating: 0, count: 64)
        data.replaceSubrange(0 ..< 4, with: Data("XXXX".utf8))

        XCTAssertThrowsError(try parseLocalNoteBody(data)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidMagic(expected: "SSNT", actual: "XXXX")
            )
        }
    }

    func testRejectsUnsupportedVersion() throws {
        var writer = ByteBuffer()
        writer.appendFixedBytes(Data(NoteMetadata.magic))
        writer.appendUInt8(99)
        writer.appendFixedBytes(uuidBytes(UUID()))
        try writer.appendLengthPrefixedString("title")
        writer.appendUInt64BE(1)
        writer.appendUInt64BE(2)
        writer.appendUInt32BE(0)
        writer.appendUInt64BE(0)
        try writer.appendLengthPrefixedBytes(Data([0x02]))

        XCTAssertThrowsError(try parseLocalNoteBody(writer.bytes)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .unsupportedVersion(99))
        }
    }

    func testMetadataParseWithoutDecryption() throws {
        let metadata = makeSampleMetadata()
        let encryptedPayload = Data(repeating: 0xEF, count: 128)
        let localBody = try assembleLocalNoteBody(
            metadata: metadata,
            encryptedPayload: encryptedPayload
        )

        let parsedMetadata = try NoteMetadata.fromLocalNoteBody(localBody)

        XCTAssertEqual(parsedMetadata, metadata)
    }

    private func makeSampleMetadata() -> NoteMetadata {
        NoteMetadata(
            noteID: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
            title: "Shopping list",
            createdAt: 1_710_000_000,
            updatedAt: 1_710_000_500,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
    }

    private func uuidBytes(_ uuid: UUID) -> Data {
        var value = uuid.uuid
        return withUnsafeBytes(of: &value) { Data($0) }
    }
}
