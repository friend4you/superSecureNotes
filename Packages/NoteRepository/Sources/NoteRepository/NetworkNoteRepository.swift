import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepositoryProtocol

public actor NetworkNoteRepository: NoteRepository {
    private let apiClient: NoteAPIClient
    private let tokenProvider: any AccessTokenProviding

    public init(
        baseURL: URL,
        tokenProvider: any AccessTokenProviding,
        session: URLSession = .shared
    ) {
        self.apiClient = NoteAPIClient(baseURL: baseURL, session: session)
        self.tokenProvider = tokenProvider
    }

    init(apiClient: NoteAPIClient, tokenProvider: any AccessTokenProviding) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    public func listNotes() async throws -> [NoteSummary] {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.listNotes(accessToken: accessToken)
    }

    public func readNote(noteID: UUID) async throws -> StoredNote {
        let accessToken = try await tokenProvider.accessToken()
        let data = try await apiClient.readNote(noteID: noteID, accessToken: accessToken)
        let sections = try parseNoteFile(data)
        return StoredNote(
            metadata: sections.metadata,
            wrappedFEK: sections.wrappedFEK,
            encryptedPayload: sections.encryptedPayload,
            syncState: .synced
        )
    }

    public func writeNote(_ note: StoredNote) async throws {
        guard !note.encryptedPayload.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        let data = try assembleNoteFile(
            metadata: note.metadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: note.encryptedPayload
        )
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.writeNote(
            noteID: note.metadata.noteID,
            data: data,
            accessToken: accessToken
        )
    }

    public func deleteNote(noteID: UUID) async throws {
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.deleteNote(noteID: noteID, accessToken: accessToken)
    }
}
