import XCTest

@testable import SecureCrypto

final class NoteFileTests: XCTestCase {
    func testAssembleAndParseRoundtrip() throws {
        let metadata = makeSampleMetadata()
        let wrappedFEK = Data(repeating: 0xAB, count: 60)
        let encryptedPayload = Data(repeating: 0xCD, count: 256)

        let noteFile = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload
        )
        let sections = try parseNoteFile(noteFile)

        XCTAssertEqual(sections.metadata, metadata)
        XCTAssertEqual(sections.wrappedFEK, wrappedFEK)
        XCTAssertEqual(sections.encryptedPayload, encryptedPayload)
    }

    func testAssembledBytesStartWithMagicAndVersion() throws {
        let noteFile = try assembleNoteFile(
            metadata: makeSampleMetadata(),
            wrappedFEK: Data([0x01]),
            encryptedPayload: Data([0x02])
        )

        XCTAssertEqual(noteFile.prefix(4), Data(NoteMetadata.magic))
        XCTAssertEqual(noteFile[4], NoteMetadata.formatVersion)
    }

    func testRejectsInvalidMagic() {
        var data = Data(repeating: 0, count: 64)
        data.replaceSubrange(0 ..< 4, with: Data("XXXX".utf8))

        XCTAssertThrowsError(try parseNoteFile(data)) { error in
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
        try writer.appendLengthPrefixedBytes(Data([0x01]))
        try writer.appendLengthPrefixedBytes(Data([0x02]))

        XCTAssertThrowsError(try parseNoteFile(writer.bytes)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .unsupportedVersion(99))
        }
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
