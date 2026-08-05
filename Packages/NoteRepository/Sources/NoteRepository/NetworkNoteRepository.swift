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
        try await uploadNote(note, ifMatch: etag, uploadSessionStore: nil)
    }

    func uploadNote(
        _ note: StoredNote,
        ifMatch etag: String?,
        uploadSessionStore: (any NoteUploadSessionStoring)?
    ) async throws -> NoteUploadResult {
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
            ifMatch: etag,
            uploadSessionStore: uploadSessionStore
        )
    }

    private func uploadNoteChunked(
        noteID: UUID,
        wireBlob: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: (any NoteUploadSessionStoring)?
    ) async throws -> NoteUploadResult {
        if let uploadSessionStore,
           let persisted = try await uploadSessionStore.fetchUploadSession(noteID: noteID) {
            if persisted.wireSize == wireBlob.count {
                do {
                    return try await resumeChunkedUpload(
                        persisted: persisted,
                        noteID: noteID,
                        wireBlob: wireBlob,
                        accessToken: accessToken,
                        ifMatch: etag,
                        uploadSessionStore: uploadSessionStore
                    )
                } catch let error where Self.isExpiredUploadSession(error) {
                    try await uploadSessionStore.deleteUploadSession(noteID: noteID)
                }
            } else {
                try await uploadSessionStore.deleteUploadSession(noteID: noteID)
            }
        }

        return try await startChunkedUpload(
            noteID: noteID,
            wireBlob: wireBlob,
            accessToken: accessToken,
            ifMatch: etag,
            uploadSessionStore: uploadSessionStore
        )
    }

    private func startChunkedUpload(
        noteID: UUID,
        wireBlob: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: (any NoteUploadSessionStoring)?
    ) async throws -> NoteUploadResult {
        let session = try await apiClient.initUpload(
            noteID: noteID,
            totalSize: wireBlob.count,
            accessToken: accessToken
        )

        if let uploadSessionStore {
            try await uploadSessionStore.upsertUploadSession(
                NoteUploadSessionRecord(
                    noteID: noteID,
                    uploadID: session.uploadID,
                    wireSize: wireBlob.count,
                    chunkSize: session.chunkSize,
                    totalChunks: session.totalChunks,
                    ifMatch: etag
                )
            )
        }

        try await uploadRemainingChunks(
            noteID: noteID,
            uploadID: session.uploadID,
            wireBlob: wireBlob,
            chunkSize: session.chunkSize,
            totalChunks: session.totalChunks,
            completedChunkIndices: [],
            accessToken: accessToken,
            uploadSessionStore: uploadSessionStore
        )

        let result = try await apiClient.completeUpload(
            noteID: noteID,
            uploadID: session.uploadID,
            accessToken: accessToken,
            ifMatch: etag
        )
        try await uploadSessionStore?.deleteUploadSession(noteID: noteID)
        return result
    }

    private func resumeChunkedUpload(
        persisted: NoteUploadSessionRecord,
        noteID: UUID,
        wireBlob: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: any NoteUploadSessionStoring
    ) async throws -> NoteUploadResult {
        try await uploadRemainingChunks(
            noteID: noteID,
            uploadID: persisted.uploadID,
            wireBlob: wireBlob,
            chunkSize: persisted.chunkSize,
            totalChunks: persisted.totalChunks,
            completedChunkIndices: persisted.completedChunkIndices,
            accessToken: accessToken,
            uploadSessionStore: uploadSessionStore
        )

        let result = try await apiClient.completeUpload(
            noteID: noteID,
            uploadID: persisted.uploadID,
            accessToken: accessToken,
            ifMatch: etag ?? persisted.ifMatch
        )
        try await uploadSessionStore.deleteUploadSession(noteID: noteID)
        return result
    }

    private func uploadRemainingChunks(
        noteID: UUID,
        uploadID: UUID,
        wireBlob: Data,
        chunkSize: Int,
        totalChunks: Int,
        completedChunkIndices: Set<Int>,
        accessToken: String,
        uploadSessionStore: (any NoteUploadSessionStoring)?
    ) async throws {
        for chunkIndex in 0..<totalChunks where !completedChunkIndices.contains(chunkIndex) {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, wireBlob.count)
            let chunkData = wireBlob.subdata(in: start..<end)
            try await uploadChunkWithRetry(
                noteID: noteID,
                uploadID: uploadID,
                chunkIndex: chunkIndex,
                chunkData: chunkData,
                accessToken: accessToken
            )
            try await uploadSessionStore?.markUploadChunkCompleted(noteID: noteID, chunkIndex: chunkIndex)
        }
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

    private static func isExpiredUploadSession(_ error: Error) -> Bool {
        guard let error = error as? NoteRepositoryError else {
            return false
        }
        switch error {
        case .noteNotFound:
            return true
        case let .serverError(statusCode):
            return statusCode == 404 || statusCode == 409 || statusCode == 410
        default:
            return false
        }
    }

    public func deleteNote(noteID: UUID) async throws {
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.deleteNote(noteID: noteID, accessToken: accessToken)
    }
}
