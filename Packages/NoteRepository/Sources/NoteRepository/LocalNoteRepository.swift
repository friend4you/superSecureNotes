import Foundation
import NoteRepositoryProtocol
import SecureCrypto

public actor LocalNoteRepository: NoteRepository {
    private static let payloadFileName = "payload"

    private let notesIndexStore: NotesIndexStore
    private let notesRootURL: URL
    private let fileManager: FileManager

    public init(
        notesIndexStore: NotesIndexStore,
        notesRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.notesIndexStore = notesIndexStore
        self.fileManager = fileManager
        if let notesRootURL {
            self.notesRootURL = notesRootURL
        } else {
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.notesRootURL = appSupport
                .appendingPathComponent("superSecureNotes", isDirectory: true)
                .appendingPathComponent("notes", isDirectory: true)
        }
    }

    public func listNotes() async throws -> [NoteSummary] {
        try await requireOpen()
        let summaries = try await notesIndexStore.listSummaries()
        return summaries.filter { $0.syncState != .pendingDelete }
    }

    public func readNote(noteID: UUID) async throws -> StoredNote {
        try await requireOpen()

        guard let row = try await notesIndexStore.fetchNote(noteID: noteID) else {
            throw NoteRepositoryError.noteNotFound
        }
        guard row.syncState != .pendingDelete else {
            throw NoteRepositoryError.noteNotFound
        }

        let payloadURL = noteDirectoryURL(for: noteID)
            .appendingPathComponent(Self.payloadFileName, isDirectory: false)
        guard fileManager.fileExists(atPath: payloadURL.path) else {
            throw NoteRepositoryError.corruptNote
        }

        let encryptedPayload = try readNotePayloadFile(from: payloadURL)
        return StoredNote(
            metadata: row.metadata,
            wrappedFEK: row.wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: row.syncState
        )
    }

    public func writeNote(_ note: StoredNote) async throws {
        try await requireOpen()

        guard !note.encryptedPayload.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        let noteID = note.metadata.noteID
        try ensureNotesRootDirectory()

        let tempDirectoryURL = notesRootURL.appendingPathComponent(
            "\(noteID.uuidString).tmp",
            isDirectory: true
        )
        let finalDirectoryURL = noteDirectoryURL(for: noteID)

        if fileManager.fileExists(atPath: tempDirectoryURL.path) {
            try fileManager.removeItem(at: tempDirectoryURL)
        }
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        try writeNotePayloadFile(
            note.encryptedPayload,
            to: tempDirectoryURL.appendingPathComponent(Self.payloadFileName, isDirectory: false)
        )

        try await notesIndexStore.upsertNote(NoteIndexRow(storedNote: note))

        if fileManager.fileExists(atPath: finalDirectoryURL.path) {
            _ = try fileManager.replaceItemAt(finalDirectoryURL, withItemAt: tempDirectoryURL)
        } else {
            try fileManager.moveItem(at: tempDirectoryURL, to: finalDirectoryURL)
        }
    }

    public func deleteNote(noteID: UUID) async throws {
        try await requireOpen()

        guard let row = try await notesIndexStore.fetchNote(noteID: noteID) else {
            throw NoteRepositoryError.noteNotFound
        }
        guard row.syncState != .pendingDelete else {
            throw NoteRepositoryError.noteNotFound
        }

        let noteDirectoryURL = noteDirectoryURL(for: noteID)
        if fileManager.fileExists(atPath: noteDirectoryURL.path) {
            try fileManager.removeItem(at: noteDirectoryURL)
        }

        try await notesIndexStore.upsertNote(
            NoteIndexRow(
                noteID: row.noteID,
                title: row.title,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                attachmentCount: row.attachmentCount,
                attachmentsTotalSize: row.attachmentsTotalSize,
                wrappedFEK: row.wrappedFEK,
                syncState: .pendingDelete,
                etag: row.etag
            )
        )
    }

    private func requireOpen() async throws {
        guard await notesIndexStore.isOpen else {
            throw NoteRepositoryError.databaseNotOpen
        }
    }

    private func noteDirectoryURL(for noteID: UUID) -> URL {
        notesRootURL.appendingPathComponent(noteID.uuidString, isDirectory: true)
    }

    private func ensureNotesRootDirectory() throws {
        try fileManager.createDirectory(
            at: notesRootURL,
            withIntermediateDirectories: true
        )
        try excludeFromBackup(notesRootURL)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
