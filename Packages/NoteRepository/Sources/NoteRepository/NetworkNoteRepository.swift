import Foundation
import NoteRepositoryProtocol
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

    public func readNote(noteID: UUID) async throws -> Data {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.readNote(noteID: noteID, accessToken: accessToken)
    }

    public func writeNote(noteID: UUID, data: Data) async throws {
        throw NoteRepositoryError.networkError
    }

    public func deleteNote(noteID: UUID) async throws {
        throw NoteRepositoryError.networkError
    }
}
