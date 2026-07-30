import Foundation
import NoteRepositoryProtocol
import SecureCrypto

public actor LocalNoteRepository: NoteRepository {
    private static let noteFileName = "note"
    private static let fekFileName = "fek"

    private let notesRootURL: URL
    private let fileManager: FileManager

    public init(notesRootURL: URL? = nil, fileManager: FileManager = .default) {
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
        try ensureNotesRootDirectory()

        let directoryURLs = try fileManager.contentsOfDirectory(
            at: notesRootURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        var summaries: [NoteSummary] = []
        for directoryURL in directoryURLs {
            let values = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let noteFileURL = directoryURL.appendingPathComponent(Self.noteFileName, isDirectory: false)
            guard fileManager.fileExists(atPath: noteFileURL.path) else { continue }

            let noteBody = try Data(contentsOf: noteFileURL)
            let metadata = try NoteMetadata.fromLocalNoteBody(noteBody)
            summaries.append(
                NoteSummary(
                    noteID: metadata.noteID,
                    title: metadata.title,
                    updatedAt: metadata.updatedAt
                )
            )
        }
        return summaries
    }

    public func readNote(noteID: UUID) async throws -> Data {
        let noteDirectoryURL = noteDirectoryURL(for: noteID)
        guard fileManager.fileExists(atPath: noteDirectoryURL.path) else {
            throw NoteRepositoryError.noteNotFound
        }

        let noteFileURL = noteDirectoryURL.appendingPathComponent(Self.noteFileName, isDirectory: false)
        let fekFileURL = noteDirectoryURL.appendingPathComponent(Self.fekFileName, isDirectory: false)
        let noteExists = fileManager.fileExists(atPath: noteFileURL.path)
        let fekExists = fileManager.fileExists(atPath: fekFileURL.path)

        guard noteExists, fekExists else {
            throw NoteRepositoryError.corruptNote
        }

        let noteBody = try Data(contentsOf: noteFileURL)
        let wrappedFEK = try Data(contentsOf: fekFileURL)
        let sections = try parseLocalNoteBody(noteBody)
        return try assembleNoteFile(
            metadata: sections.metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: sections.encryptedPayload
        )
    }

    public func writeNote(noteID: UUID, data: Data) async throws {
        guard !data.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        let wireSections = try parseNoteFile(data)
        guard wireSections.metadata.noteID == noteID else {
            throw NoteRepositoryError.validationError("Note ID mismatch.")
        }

        let localNoteBody = try assembleLocalNoteBody(
            metadata: wireSections.metadata,
            encryptedPayload: wireSections.encryptedPayload
        )

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

        try localNoteBody.write(
            to: tempDirectoryURL.appendingPathComponent(Self.noteFileName, isDirectory: false),
            options: .atomic
        )
        try wireSections.wrappedFEK.write(
            to: tempDirectoryURL.appendingPathComponent(Self.fekFileName, isDirectory: false),
            options: .atomic
        )

        if fileManager.fileExists(atPath: finalDirectoryURL.path) {
            _ = try fileManager.replaceItemAt(finalDirectoryURL, withItemAt: tempDirectoryURL)
        } else {
            try fileManager.moveItem(at: tempDirectoryURL, to: finalDirectoryURL)
        }
    }

    public func deleteNote(noteID: UUID) async throws {
        let noteDirectoryURL = noteDirectoryURL(for: noteID)
        guard fileManager.fileExists(atPath: noteDirectoryURL.path) else {
            throw NoteRepositoryError.noteNotFound
        }
        try fileManager.removeItem(at: noteDirectoryURL)
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
