import Foundation
import NoteRepositoryProtocol
import SecureCrypto

extension LocalNoteRepository {
    static let sharedBodyFileName = "body"
    static let sharedWrappedFEKFileName = "wrapped_fek"
    static let sharedAttachmentsDirectoryName = "attachments"

    var sharedRootURL: URL {
        notesRootURL
            .deletingLastPathComponent()
            .appendingPathComponent("shared", isDirectory: true)
    }

    nonisolated public func setSharedBodyImporter(_ importer: NetworkNoteRepository) {
        sharedBodyImporter = importer
    }

    nonisolated func setSharedBodyImporter(_ importer: any SharedNoteBodyImporting) {
        sharedBodyImporter = importer
    }

    func sharedNoteDirectoryURL(for noteID: UUID) -> URL {
        sharedRootURL.appendingPathComponent(noteID.uuidString, isDirectory: true)
    }

    func sharedBodyFileURL(for noteID: UUID) -> URL {
        sharedNoteDirectoryURL(for: noteID)
            .appendingPathComponent(Self.sharedBodyFileName, isDirectory: false)
    }

    func sharedWrappedFEKFileURL(for noteID: UUID) -> URL {
        sharedNoteDirectoryURL(for: noteID)
            .appendingPathComponent(Self.sharedWrappedFEKFileName, isDirectory: false)
    }

    func sharedAttachmentsDirectoryURL(for noteID: UUID) -> URL {
        sharedNoteDirectoryURL(for: noteID)
            .appendingPathComponent(Self.sharedAttachmentsDirectoryName, isDirectory: true)
    }

    func writeSharedBodyFile(_ bodyData: Data, noteID: UUID) throws {
        try ensureSharedRootDirectory()
        let noteDirectory = sharedNoteDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: noteDirectory.path) {
            try fileManager.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
            try excludeFromBackup(noteDirectory)
        }
        try writeNoteBodyFile(bodyData, to: sharedBodyFileURL(for: noteID))
    }

    func readSharedBodyFile(noteID: UUID) throws -> Data {
        try readNoteBodyFile(from: sharedBodyFileURL(for: noteID))
    }

    func writeSharedWrappedFEKFile(_ wrappedFEK: Data, noteID: UUID) throws {
        try ensureSharedRootDirectory()
        let noteDirectory = sharedNoteDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: noteDirectory.path) {
            try fileManager.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
            try excludeFromBackup(noteDirectory)
        }
        let url = sharedWrappedFEKFileURL(for: noteID)
        try wrappedFEK.write(to: url, options: .atomic)
    }

    func readSharedWrappedFEKFile(noteID: UUID) throws -> Data {
        let url = sharedWrappedFEKFileURL(for: noteID)
        guard fileManager.fileExists(atPath: url.path) else {
            throw NoteRepositoryError.noteNotFound
        }
        return try Data(contentsOf: url)
    }

    func persistSharedAttachmentCiphertext(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data
    ) throws {
        guard !ciphertext.isEmpty else {
            throw NoteRepositoryError.validationError("Attachment must not be empty.")
        }
        try ensureSharedRootDirectory()
        let noteDirectory = sharedNoteDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: noteDirectory.path) {
            try fileManager.createDirectory(at: noteDirectory, withIntermediateDirectories: true)
            try excludeFromBackup(noteDirectory)
        }
        let attachmentsDir = sharedAttachmentsDirectoryURL(for: noteID)
        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
            try excludeFromBackup(attachmentsDir)
        }
        let attachmentURL = attachmentsDir.appendingPathComponent(
            attachmentID.uuidString,
            isDirectory: false
        )
        try ciphertext.write(to: attachmentURL, options: .atomic)
    }

    func readSharedAttachmentFile(noteID: UUID, attachmentID: UUID) throws -> Data? {
        let url = sharedAttachmentsDirectoryURL(for: noteID)
            .appendingPathComponent(attachmentID.uuidString, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    func sharedAttachmentFileExists(noteID: UUID, attachmentID: UUID) -> Bool {
        let url = sharedAttachmentsDirectoryURL(for: noteID)
            .appendingPathComponent(attachmentID.uuidString, isDirectory: false)
        return fileManager.fileExists(atPath: url.path)
    }

    func purgeSharedNoteDirectory(noteID: UUID) throws {
        let directory = sharedNoteDirectoryURL(for: noteID)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    func loadSharedAttachmentCiphertextsFromDisk(noteID: UUID) throws -> [UUID: Data] {
        let attachmentsDir = sharedAttachmentsDirectoryURL(for: noteID)
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

    private func ensureSharedRootDirectory() throws {
        try fileManager.createDirectory(
            at: sharedRootURL,
            withIntermediateDirectories: true
        )
        try excludeFromBackup(sharedRootURL)
    }
}
