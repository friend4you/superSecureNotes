import Foundation
import NoteRepositoryProtocol
import SecureCrypto

#if DEBUG

actor FileNoteRepository: NoteRepository {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directoryURL = appSupport.appendingPathComponent("stub-notes", isDirectory: true)
        }
    }

    func listNotes() async throws -> [NoteSummary] {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        var summaries: [NoteSummary] = []
        for fileURL in fileURLs where fileURL.pathExtension == "note" {
            let data = try Data(contentsOf: fileURL)
            let metadata = try NoteMetadata.fromNoteFile(data)
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

    func readNote(noteID: UUID) async throws -> Data {
        let fileURL = noteFileURL(for: noteID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NoteRepositoryError.noteNotFound
        }
        return try Data(contentsOf: fileURL)
    }

    func writeNote(noteID: UUID, data: Data) async throws {
        guard !data.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: noteFileURL(for: noteID), options: .atomic)
    }

    func deleteNote(noteID: UUID) async throws {
        let fileURL = noteFileURL(for: noteID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NoteRepositoryError.noteNotFound
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func noteFileURL(for noteID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(noteID.uuidString).note", isDirectory: false)
    }
}

#endif
