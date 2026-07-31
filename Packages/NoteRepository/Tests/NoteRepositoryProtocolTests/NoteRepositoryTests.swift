import SecureCrypto
import XCTest

@testable import NoteRepositoryProtocol

final class NoteRepositoryTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let repository = MockNoteRepository()
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let summary = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1_700_000_000)
        let storedNote = makeStoredNote(noteID: noteID)

        try await repository.openDatabase(passphrase: Data([0x01]))
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

        await repository.closeDatabase()
    }

    func testMockActorRejectsCRUDBeforeOpen() async {
        let repository = MockNoteRepository()
        let noteID = UUID()

        do {
            _ = try await repository.listNotes()
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await repository.readNote(noteID: noteID)
            XCTFail("Expected databaseNotOpen")
        } catch NoteRepositoryError.databaseNotOpen {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
    private var isOpen = false
    private var notes: [NoteSummary] = []
    private var storedNote: StoredNote?

    func setNotes(_ notes: [NoteSummary]) {
        self.notes = notes
    }

    func setStoredNote(_ storedNote: StoredNote) {
        self.storedNote = storedNote
    }

    func openDatabase(passphrase: Data) async throws {
        _ = passphrase
        isOpen = true
    }

    func closeDatabase() async {
        isOpen = false
    }

    func listNotes() async throws -> [NoteSummary] {
        try requireOpen()
        return notes
    }

    func readNote(noteID: UUID) async throws -> StoredNote {
        try requireOpen()
        _ = noteID
        guard let storedNote else {
            throw NoteRepositoryError.noteNotFound
        }
        return storedNote
    }

    func writeNote(_ note: StoredNote) async throws {
        try requireOpen()
        storedNote = note
    }

    func deleteNote(noteID: UUID) async throws {
        try requireOpen()
        _ = noteID
        notes = []
        storedNote = nil
    }

    private func requireOpen() throws {
        guard isOpen else {
            throw NoteRepositoryError.databaseNotOpen
        }
    }
}
