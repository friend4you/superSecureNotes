import XCTest

@testable import SecureCrypto

final class NoteFileSplitTests: XCTestCase {
    func testSplitThenReassemblePreservesWireBlob() throws {
        let metadata = makeSampleMetadata()
        let wrappedFEK = Data(repeating: 0xAB, count: 60)
        let encryptedPayload = Data(repeating: 0xCD, count: 256)
        let wireBlob = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload
        )

        let sections = try splitNoteFile(wireBlob)
        let reassembled = try assembleNoteFile(
            metadata: sections.metadata,
            wrappedFEK: sections.wrappedFEK,
            encryptedPayload: sections.encryptedPayload
        )

        XCTAssertEqual(reassembled, wireBlob)
    }

    func testSplitMatchesParseNoteFile() throws {
        let wireBlob = try assembleNoteFile(
            metadata: makeSampleMetadata(),
            wrappedFEK: Data(repeating: 0x11, count: 48),
            encryptedPayload: Data(repeating: 0x22, count: 96)
        )

        let split = try splitNoteFile(wireBlob)
        let parsed = try parseNoteFile(wireBlob)

        XCTAssertEqual(split.metadata, parsed.metadata)
        XCTAssertEqual(split.wrappedFEK, parsed.wrappedFEK)
        XCTAssertEqual(split.encryptedPayload, parsed.encryptedPayload)
    }

    private func makeSampleMetadata() -> NoteMetadata {
        NoteMetadata(
            noteID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
            title: "Split test note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
    }
}
