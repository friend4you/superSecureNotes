import CryptoKit
import Foundation
import NoteRepositoryProtocol
import SecureCrypto

public actor LocalNoteRepository: NoteRepository, InlineAttachmentMigrating {
    private static let bodyFileName = "body"
    private static let attachmentsDirectoryName = "attachments"
    private static let legacyPayloadFileName = "payload"

    let notesIndexStore: NotesIndexStore
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

        let noteDirectory = noteDirectoryURL(for: noteID)
        let bodyURL = bodyFileURL(in: noteDirectory)
        let legacyPayloadURL = noteDirectory.appendingPathComponent(
            Self.legacyPayloadFileName,
            isDirectory: false
        )

        let wrappedFEK: Data
        let encryptedPayload: Data

        if fileManager.fileExists(atPath: bodyURL.path) {
            let bodyData = try readNoteBodyFile(from: bodyURL)
            let sections = try parseNoteFile(bodyData)
            guard sections.metadata.noteID == noteID else {
                throw NoteRepositoryError.corruptNote
            }
            wrappedFEK = sections.wrappedFEK
            encryptedPayload = sections.encryptedPayload
        } else if fileManager.fileExists(atPath: legacyPayloadURL.path) {
            encryptedPayload = try readNotePayloadFile(from: legacyPayloadURL)
            wrappedFEK = row.wrappedFEK
            try await migrateLegacyPayloadLayout(
                noteID: noteID,
                row: row,
                encryptedPayload: encryptedPayload
            )
        } else {
            throw NoteRepositoryError.corruptNote
        }

        let attachmentCiphertexts = try loadAttachmentCiphertexts(noteID: noteID)

        return StoredNote(
            metadata: row.metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: row.syncState,
            attachmentCiphertexts: attachmentCiphertexts
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

        let bodyData = try assembleNoteFile(
            metadata: note.metadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: note.encryptedPayload
        )
        try writeNoteBodyFile(
            bodyData,
            to: tempDirectoryURL.appendingPathComponent(Self.bodyFileName, isDirectory: false)
        )

        if !note.attachmentCiphertexts.isEmpty {
            let attachmentsDir = tempDirectoryURL.appendingPathComponent(
                Self.attachmentsDirectoryName,
                isDirectory: true
            )
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
            for (attachmentID, ciphertext) in note.attachmentCiphertexts {
                guard !ciphertext.isEmpty else {
                    throw NoteRepositoryError.validationError("Attachment must not be empty.")
                }
                let attachmentURL = attachmentsDir.appendingPathComponent(
                    attachmentID.uuidString,
                    isDirectory: false
                )
                try ciphertext.write(to: attachmentURL, options: .atomic)
            }
        }

        try await notesIndexStore.upsertNote(NoteIndexRow(storedNote: note))
        try await syncAttachmentIndexRows(noteID: noteID, ciphertexts: note.attachmentCiphertexts)

        if fileManager.fileExists(atPath: finalDirectoryURL.path) {
            _ = try fileManager.replaceItemAt(finalDirectoryURL, withItemAt: tempDirectoryURL)
        } else {
            try fileManager.moveItem(at: tempDirectoryURL, to: finalDirectoryURL)
        }
    }

    /// Migrates a v1 inline-attachment payload to split storage. Caller supplies the note FEK.
    public func migrateInlineAttachmentsToSplit(noteID: UUID, fek: SymmetricKey) async throws {
        try await requireOpen()
        let note = try await readNote(noteID: noteID)
        let payload = try decryptPayload(note.encryptedPayload, with: fek)

        let hasInlineData = payload.attachments.contains { $0.data != nil }
        guard payload.schemaVersion == 1 || hasInlineData else {
            return
        }
        guard hasInlineData else {
            return
        }

        let migrated = try migratePayloadV1ToV2(payload)
        let encryptedPayload = try encryptPayload(migrated.payload, with: fek)

        var attachmentCiphertexts: [UUID: Data] = [:]
        for (idString, plaintext) in migrated.attachmentBytes {
            guard let attachmentID = UUID(uuidString: idString) else {
                throw NoteRepositoryError.validationError("Migrated attachment id must be a UUID.")
            }
            attachmentCiphertexts[attachmentID] = try encryptAttachmentFile(plaintext, with: fek)
        }

        let updatedMetadata = NoteMetadata(
            noteID: note.metadata.noteID,
            title: note.metadata.title,
            createdAt: note.metadata.createdAt,
            updatedAt: note.metadata.updatedAt,
            attachmentCount: UInt32(attachmentCiphertexts.count),
            attachmentsTotalSize: attachmentCiphertexts.values.reduce(0) { $0 + UInt64($1.count) }
        )

        let migratedNote = StoredNote(
            metadata: updatedMetadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync,
            attachmentCiphertexts: attachmentCiphertexts
        )
        try await writeNote(migratedNote)
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

        try await notesIndexStore.deleteAttachments(noteID: noteID)
        try await notesIndexStore.deleteAttachmentUploadSessions(noteID: noteID)

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
                bodyEtag: row.bodyEtag,
                etag: row.etag
            )
        )
    }

    public func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        _ = noteID
        _ = recipientEmail
        _ = wrappedFEK
        throw NoteRepositoryError.notSupported
    }

    public func listSharedNotes() async throws -> [SharedNoteSummary] {
        []
    }

    public func readSharedNote(noteID: UUID) async throws -> SharedNote {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    public func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func requireOpen() async throws {
        guard await notesIndexStore.isOpen else {
            throw NoteRepositoryError.databaseNotOpen
        }
    }

    private func noteDirectoryURL(for noteID: UUID) -> URL {
        notesRootURL.appendingPathComponent(noteID.uuidString, isDirectory: true)
    }

    private func bodyFileURL(in noteDirectory: URL) -> URL {
        noteDirectory.appendingPathComponent(Self.bodyFileName, isDirectory: false)
    }

    private func attachmentsDirectoryURL(for noteID: UUID) -> URL {
        noteDirectoryURL(for: noteID)
            .appendingPathComponent(Self.attachmentsDirectoryName, isDirectory: true)
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

    private func loadAttachmentCiphertexts(noteID: UUID) throws -> [UUID: Data] {
        let attachmentsDir = attachmentsDirectoryURL(for: noteID)
        guard fileManager.fileExists(atPath: attachmentsDir.path) else {
            return [:]
        }

        let contents = try fileManager.contentsOfDirectory(
            at: attachmentsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var result: [UUID: Data] = [:]
        for url in contents {
            guard let attachmentID = UUID(uuidString: url.lastPathComponent) else {
                continue
            }
            result[attachmentID] = try Data(contentsOf: url)
        }
        return result
    }

    func attachmentFileExists(noteID: UUID, attachmentID: UUID) -> Bool {
        let url = attachmentsDirectoryURL(for: noteID)
            .appendingPathComponent(attachmentID.uuidString, isDirectory: false)
        return fileManager.fileExists(atPath: url.path)
    }

    func listAttachmentIndexRows(noteID: UUID) async throws -> [AttachmentIndexRow] {
        try await requireOpen()
        return try await notesIndexStore.listAttachments(noteID: noteID)
    }

    func writeAttachmentFile(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        etag: String?
    ) async throws {
        try await requireOpen()
        guard !ciphertext.isEmpty else {
            throw NoteRepositoryError.validationError("Attachment must not be empty.")
        }

        try ensureNotesRootDirectory()
        let noteDirectory = noteDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: noteDirectory.path) {
            try fileManager.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
            try excludeFromBackup(noteDirectory)
        }

        let attachmentsDir = attachmentsDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
            try excludeFromBackup(attachmentsDir)
        }

        let attachmentURL = attachmentsDir.appendingPathComponent(
            attachmentID.uuidString,
            isDirectory: false
        )
        try ciphertext.write(to: attachmentURL, options: .atomic)

        try await notesIndexStore.upsertAttachment(
            AttachmentIndexRow(
                noteID: noteID,
                attachmentID: attachmentID,
                etag: etag,
                sizeBytes: UInt64(ciphertext.count),
                syncState: .synced
            )
        )
    }

    private func syncAttachmentIndexRows(noteID: UUID, ciphertexts: [UUID: Data]) async throws {
        let existing = try await notesIndexStore.listAttachments(noteID: noteID)
        let existingIDs = Set(existing.map(\.attachmentID))
        let newIDs = Set(ciphertexts.keys)

        for removedID in existingIDs.subtracting(newIDs) {
            try await notesIndexStore.deleteAttachment(noteID: noteID, attachmentID: removedID)
        }

        for (attachmentID, ciphertext) in ciphertexts {
            try await notesIndexStore.upsertAttachment(
                AttachmentIndexRow(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    etag: existing.first { $0.attachmentID == attachmentID }?.etag,
                    sizeBytes: UInt64(ciphertext.count),
                    syncState: .pendingSync
                )
            )
        }
    }

    private func migrateLegacyPayloadLayout(
        noteID: UUID,
        row: NoteIndexRow,
        encryptedPayload: Data
    ) async throws {
        let noteDirectory = noteDirectoryURL(for: noteID)
        let tempDirectoryURL = notesRootURL.appendingPathComponent(
            "\(noteID.uuidString).migrate.tmp",
            isDirectory: true
        )
        if fileManager.fileExists(atPath: tempDirectoryURL.path) {
            try fileManager.removeItem(at: tempDirectoryURL)
        }
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        let bodyData = try assembleNoteFile(
            metadata: row.metadata,
            wrappedFEK: row.wrappedFEK,
            encryptedPayload: encryptedPayload
        )
        try writeNoteBodyFile(
            bodyData,
            to: tempDirectoryURL.appendingPathComponent(Self.bodyFileName, isDirectory: false)
        )

        _ = try fileManager.replaceItemAt(noteDirectory, withItemAt: tempDirectoryURL)
    }
}
