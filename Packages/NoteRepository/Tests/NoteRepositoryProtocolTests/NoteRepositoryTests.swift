import XCTest

@testable import NoteRepositoryProtocol

final class NoteRepositoryTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let repository = MockNoteRepository()
        let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        let noteData = Data([0x01, 0x02, 0x03])
        let summary = NoteSummary(noteID: noteID, title: "My note", updatedAt: 1_700_000_000)

        await repository.setNotes([summary])
        await repository.setNoteData(noteData)

        let notes = try await repository.listNotes()
        XCTAssertEqual(notes, [summary])

        let readData = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(readData, noteData)

        try await repository.writeNote(noteID: noteID, data: Data([0x04]))
        let updatedData = try await repository.readNote(noteID: noteID)
        XCTAssertEqual(updatedData, Data([0x04]))

        try await repository.deleteNote(noteID: noteID)
        let notesAfterDelete = try await repository.listNotes()
        XCTAssertTrue(notesAfterDelete.isEmpty)
    }
}

private actor MockNoteRepository: NoteRepository {
    private var notes: [NoteSummary] = []
    private var noteData = Data()

    func setNotes(_ notes: [NoteSummary]) {
        self.notes = notes
    }

    func setNoteData(_ noteData: Data) {
        self.noteData = noteData
    }

    func listNotes() async throws -> [NoteSummary] {
        notes
    }

    func readNote(noteID: UUID) async throws -> Data {
        noteData
    }

    func writeNote(noteID: UUID, data: Data) async throws {
        noteData = data
    }

    func deleteNote(noteID: UUID) async throws {
        notes = []
        noteData = Data()
    }
}
