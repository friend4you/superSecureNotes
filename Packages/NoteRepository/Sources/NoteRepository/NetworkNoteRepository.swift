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
        _ = try await uploadNote(note)
    }

    public func uploadNote(_ note: StoredNote, ifMatch etag: String? = nil) async throws -> NoteUploadResult {
        guard !note.encryptedPayload.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        let data = try assembleNoteFile(
            metadata: note.metadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: note.encryptedPayload
        )
        let accessToken = try await tokenProvider.accessToken()
        if data.count <= NoteUploadSizeThreshold {
            return try await apiClient.writeNote(
                noteID: note.metadata.noteID,
                data: data,
                accessToken: accessToken,
                ifMatch: etag
            )
        }
        return try await uploadNoteChunked(
            noteID: note.metadata.noteID,
            wireBlob: data,
            accessToken: accessToken,
            ifMatch: etag
        )
    }

    private func uploadNoteChunked(
        noteID: UUID,
        wireBlob: Data,
        accessToken: String,
        ifMatch etag: String?
    ) async throws -> NoteUploadResult {
        let session = try await apiClient.initUpload(
            noteID: noteID,
            totalSize: wireBlob.count,
            accessToken: accessToken
        )

        for chunkIndex in 0..<session.totalChunks {
            let start = chunkIndex * session.chunkSize
            let end = min(start + session.chunkSize, wireBlob.count)
            let chunkData = wireBlob.subdata(in: start..<end)
            try await uploadChunkWithRetry(
                noteID: noteID,
                uploadID: session.uploadID,
                chunkIndex: chunkIndex,
                chunkData: chunkData,
                accessToken: accessToken
            )
        }

        return try await apiClient.completeUpload(
            noteID: noteID,
            uploadID: session.uploadID,
            accessToken: accessToken,
            ifMatch: etag
        )
    }

    private func uploadChunkWithRetry(
        noteID: UUID,
        uploadID: UUID,
        chunkIndex: Int,
        chunkData: Data,
        accessToken: String
    ) async throws {
        while true {
            do {
                try await apiClient.uploadChunk(
                    noteID: noteID,
                    uploadID: uploadID,
                    chunkIndex: chunkIndex,
                    data: chunkData,
                    accessToken: accessToken
                )
                return
            } catch NoteRepositoryError.networkError {
                continue
            }
        }
    }

    public func deleteNote(noteID: UUID) async throws {
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.deleteNote(noteID: noteID, accessToken: accessToken)
    }
}
