import CryptoKit
import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

enum NoteViewModelTestSupport {
    static func makeStoredNote(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey,
        attachments: [NotePayload.Attachment] = [],
        createdAt: UInt64 = 1_700_000_000,
        updatedAt: UInt64 = 1_700_000_100,
        syncState: NoteSyncState = .pendingSync
    ) throws -> StoredNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(attachments.count),
            attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
        )
        return StoredNote(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: syncState
        )
    }
}

actor StoredNoteMockRepository: NoteRepository {
    private var notes: [UUID: StoredNote]
    private(set) var writtenNotes: [StoredNote] = []
    private(set) var deletedNoteIDs: [UUID] = []
    private(set) var listNotesCallCount = 0

    init(notes: [UUID: StoredNote] = [:]) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] {
        listNotesCallCount += 1
        return notes.values.map {
            NoteSummary(
                noteID: $0.metadata.noteID,
                title: $0.metadata.title,
                updatedAt: $0.metadata.updatedAt
            )
        }
    }

    func readNote(noteID: UUID) async throws -> StoredNote {
        guard let note = notes[noteID] else {
            throw NoteRepositoryError.noteNotFound
        }
        return note
    }

    func writeNote(_ note: StoredNote) async throws {
        writtenNotes.append(note)
        notes[note.metadata.noteID] = note
    }

    func deleteNote(noteID: UUID) async throws {
        deletedNoteIDs.append(noteID)
        notes.removeValue(forKey: noteID)
    }

    func storedNote(noteID: UUID) async throws -> StoredNote {
        try await readNote(noteID: noteID)
    }
}

actor StoredNoteMockVaultSession: VaultSessionProtocol {
    private let key: SymmetricKey

    init(udk: SymmetricKey = SymmetricKey(size: .bits256)) {
        key = udk
    }

    var isActive: Bool { true }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { key }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}
