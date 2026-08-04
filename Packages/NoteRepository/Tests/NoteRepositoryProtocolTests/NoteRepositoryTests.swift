import SecureCrypto
import XCTest

@testable import NoteRepositoryProtocol

final class NoteRepositoryTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let repository = MockNoteRepository()
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let summary = NoteSummary(
            noteID: noteID,
            title: "My note",
            updatedAt: 1_700_000_000,
            syncState: .synced
        )
        let storedNote = makeStoredNote(noteID: noteID)

        await repository.setNotes([summary])
        await repository.setStoredNote(storedNote)

        let notes = try await repository.listNotes()
        XCTAssertEqual(notes, [summary])

        let readNote = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(readNote, storedNote)

        let updatedNote = StoredNote(
            metadata: storedNote.metadata,
            wrappedFEK: Data([0x09]),
            encryptedPayload: Data([0x04]),
            syncState: .pendingSync
        )
        try await repository.writeNote(updatedNote)
        let updatedRead = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(updatedRead, updatedNote)

        try await repository.deleteNote(noteID: noteID)
        let notesAfterDelete = try await repository.listNotes()
        XCTAssertTrue(notesAfterDelete.isEmpty)
    }

    private func makeStoredNote(noteID: UUID) -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "My note",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_000,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data([0x01, 0x02, 0x03]),
            encryptedPayload: Data([0xAA, 0xBB]),
            syncState: .pendingSync
        )
    }
}

private actor MockNoteRepository: NoteRepository {
    private var notes: [NoteSummary] = []
    private var storedNote: StoredNote?

    func setNotes(_ notes: [NoteSummary]) {
        self.notes = notes
    }

    func setStoredNote(_ storedNote: StoredNote) {
        self.storedNote = storedNote
    }

    func listNotes() async throws -> [NoteSummary] {
        notes
    }

    func readNote(noteID: UUID) async throws -> StoredNote {
        _ = noteID
        guard let storedNote else {
            throw NoteRepositoryError.noteNotFound
        }
        return storedNote
    }

    func writeNote(_ note: StoredNote) async throws {
        storedNote = note
    }

    func deleteNote(noteID: UUID) async throws {
        _ = noteID
        notes = []
        storedNote = nil
    }
}
