import XCTest

@testable import SecureCrypto

final class NoteMetadataTests: XCTestCase {
    func testMetadataRoundtripViaFromNoteFile() throws {
        let metadata = makeSampleMetadata()
        let noteFile = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: Data(repeating: 0x01, count: 60),
            encryptedPayload: Data(repeating: 0x02, count: 128)
        )

        let parsed = try NoteMetadata.fromNoteFile(noteFile)

        XCTAssertEqual(parsed, metadata)
    }

    private func makeSampleMetadata() -> NoteMetadata {
        NoteMetadata(
            noteID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
            title: "My secure note",
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 2,
            attachmentsTotalSize: 4_096
        )
    }
}
