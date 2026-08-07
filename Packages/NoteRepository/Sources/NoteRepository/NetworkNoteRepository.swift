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
        let data = try await apiClient.readBody(noteID: noteID, accessToken: accessToken)
        let sections = try parseNoteFile(data)
        return StoredNote(
            metadata: sections.metadata,
            wrappedFEK: sections.wrappedFEK,
            encryptedPayload: sections.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: [:]
        )
    }

    public func readAttachment(noteID: UUID, attachmentID: UUID) async throws -> Data {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.readAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            accessToken: accessToken
        )
    }

    func listAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary] {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.listAttachments(noteID: noteID, accessToken: accessToken)
    }

    func listSharedAttachments(noteID: UUID) async throws -> [RemoteAttachmentSummary] {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.listSharedAttachments(noteID: noteID, accessToken: accessToken)
    }

    func readSharedAttachment(noteID: UUID, attachmentID: UUID) async throws -> Data {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.readSharedAttachment(
            noteID: noteID,
            attachmentID: attachmentID,
            accessToken: accessToken
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
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> NoteUploadResult {
        guard !note.encryptedPayload.isEmpty else {
            throw NoteRepositoryError.validationError("Note must not be empty.")
        }

        let bodyData = try assembleNoteFile(
            metadata: note.metadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: note.encryptedPayload
        )
        let accessToken = try await tokenProvider.accessToken()
        var result = try await apiClient.writeBody(
            noteID: note.metadata.noteID,
            data: bodyData,
            accessToken: accessToken,
            ifMatch: etag
        )

        let attachmentEntries = note.attachmentCiphertexts.sorted {
            $0.key.uuidString.lowercased() < $1.key.uuidString.lowercased()
        }
        for (attachmentID, ciphertext) in attachmentEntries {
            let attachmentResult = try await uploadAttachment(
                noteID: note.metadata.noteID,
                attachmentID: attachmentID,
                ciphertext: ciphertext,
                accessToken: accessToken,
                ifMatch: nil,
                uploadSessionStore: uploadSessionStore
            )
            if let noteEtag = attachmentResult.noteEtag {
                result = NoteUploadResult(
                    syncState: result.syncState,
                    updatedAt: result.updatedAt,
                    etag: noteEtag
                )
            }
        }

        try await deleteRemovedAttachments(
            noteID: note.metadata.noteID,
            localAttachmentIDs: Set(note.attachmentCiphertexts.keys),
            accessToken: accessToken
        )

        return result
    }

    private func deleteRemovedAttachments(
        noteID: UUID,
        localAttachmentIDs: Set<UUID>,
        accessToken: String
    ) async throws {
        let remoteAttachments: [RemoteAttachmentSummary]
        do {
            remoteAttachments = try await apiClient.listAttachments(
                noteID: noteID,
                accessToken: accessToken
            )
        } catch NoteRepositoryError.noteNotFound {
            return
        }

        for remote in remoteAttachments where !localAttachmentIDs.contains(remote.attachmentID) {
            try await apiClient.deleteAttachment(
                noteID: noteID,
                attachmentID: remote.attachmentID,
                accessToken: accessToken
            )
        }
    }

    private func uploadAttachment(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> AttachmentUploadResult {
        if ciphertext.count <= NoteUploadSizeThreshold {
            return try await apiClient.writeAttachment(
                noteID: noteID,
                attachmentID: attachmentID,
                data: ciphertext,
                accessToken: accessToken,
                ifMatch: etag
            )
        }
        return try await uploadAttachmentChunked(
            noteID: noteID,
            attachmentID: attachmentID,
            ciphertext: ciphertext,
            accessToken: accessToken,
            ifMatch: etag,
            uploadSessionStore: uploadSessionStore
        )
    }

    private func uploadAttachmentChunked(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> AttachmentUploadResult {
        if let uploadSessionStore,
           let persisted = try await uploadSessionStore.fetchAttachmentUploadSession(
               noteID: noteID,
               attachmentID: attachmentID
           ) {
            if persisted.wireSize == ciphertext.count {
                do {
                    return try await resumeAttachmentChunkedUpload(
                        persisted: persisted,
                        noteID: noteID,
                        attachmentID: attachmentID,
                        ciphertext: ciphertext,
                        accessToken: accessToken,
                        ifMatch: etag,
                        uploadSessionStore: uploadSessionStore
                    )
                } catch let error where Self.isExpiredUploadSession(error) {
                    try await uploadSessionStore.deleteAttachmentUploadSession(
                        noteID: noteID,
                        attachmentID: attachmentID
                    )
                }
            } else {
                try await uploadSessionStore.deleteAttachmentUploadSession(
                    noteID: noteID,
                    attachmentID: attachmentID
                )
            }
        }

        return try await startAttachmentChunkedUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            ciphertext: ciphertext,
            accessToken: accessToken,
            ifMatch: etag,
            uploadSessionStore: uploadSessionStore
        )
    }

    private func startAttachmentChunkedUpload(
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws -> AttachmentUploadResult {
        let session = try await apiClient.initAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            totalSize: ciphertext.count,
            accessToken: accessToken
        )

        if let uploadSessionStore {
            try await uploadSessionStore.upsertAttachmentUploadSession(
                AttachmentUploadSessionRecord(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    uploadID: session.uploadID,
                    wireSize: ciphertext.count,
                    chunkSize: session.chunkSize,
                    totalChunks: session.totalChunks,
                    ifMatch: etag
                )
            )
        }

        try await uploadRemainingAttachmentChunks(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: session.uploadID,
            ciphertext: ciphertext,
            chunkSize: session.chunkSize,
            totalChunks: session.totalChunks,
            completedChunkIndices: [],
            accessToken: accessToken,
            uploadSessionStore: uploadSessionStore
        )

        let result = try await apiClient.completeAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: session.uploadID,
            accessToken: accessToken,
            ifMatch: etag
        )
        try await uploadSessionStore?.deleteAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        return result
    }

    private func resumeAttachmentChunkedUpload(
        persisted: AttachmentUploadSessionRecord,
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        accessToken: String,
        ifMatch etag: String?,
        uploadSessionStore: any AttachmentUploadSessionStoring
    ) async throws -> AttachmentUploadResult {
        try await uploadRemainingAttachmentChunks(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: persisted.uploadID,
            ciphertext: ciphertext,
            chunkSize: persisted.chunkSize,
            totalChunks: persisted.totalChunks,
            completedChunkIndices: persisted.completedChunkIndices,
            accessToken: accessToken,
            uploadSessionStore: uploadSessionStore
        )

        let result = try await apiClient.completeAttachmentUpload(
            noteID: noteID,
            attachmentID: attachmentID,
            uploadID: persisted.uploadID,
            accessToken: accessToken,
            ifMatch: etag ?? persisted.ifMatch
        )
        try await uploadSessionStore.deleteAttachmentUploadSession(
            noteID: noteID,
            attachmentID: attachmentID
        )
        return result
    }

    private func uploadRemainingAttachmentChunks(
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        ciphertext: Data,
        chunkSize: Int,
        totalChunks: Int,
        completedChunkIndices: Set<Int>,
        accessToken: String,
        uploadSessionStore: (any AttachmentUploadSessionStoring)?
    ) async throws {
        for chunkIndex in 0..<totalChunks where !completedChunkIndices.contains(chunkIndex) {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, ciphertext.count)
            let chunkData = ciphertext.subdata(in: start..<end)
            try await uploadAttachmentChunkWithRetry(
                noteID: noteID,
                attachmentID: attachmentID,
                uploadID: uploadID,
                chunkIndex: chunkIndex,
                chunkData: chunkData,
                accessToken: accessToken
            )
            try await uploadSessionStore?.markAttachmentUploadChunkCompleted(
                noteID: noteID,
                attachmentID: attachmentID,
                chunkIndex: chunkIndex
            )
        }
    }

    private func uploadAttachmentChunkWithRetry(
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        chunkIndex: Int,
        chunkData: Data,
        accessToken: String
    ) async throws {
        while true {
            do {
                try await apiClient.uploadAttachmentChunk(
                    noteID: noteID,
                    attachmentID: attachmentID,
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

    public func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.shareNote(
            noteID: noteID,
            recipientEmail: recipientEmail,
            wrappedFEK: wrappedFEK,
            accessToken: accessToken
        )
    }

    public func listSharedNotes() async throws -> [SharedNoteSummary] {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.listSharedNotes(accessToken: accessToken)
    }

    public func readSharedNote(noteID: UUID) async throws -> SharedNote {
        let accessToken = try await tokenProvider.accessToken()
        let dto = try await apiClient.readSharedNote(noteID: noteID, accessToken: accessToken)

        guard let responseNoteID = UUID(uuidString: dto.noteId) else {
            throw NoteRepositoryError.validationError("Invalid note ID in shared note response.")
        }
        guard let blobData = Data(base64Encoded: dto.blob) else {
            throw NoteRepositoryError.validationError("Invalid shared note blob encoding.")
        }
        guard let recipientWrappedFEK = Data(base64Encoded: dto.wrappedFek) else {
            throw NoteRepositoryError.validationError("Invalid shared note wrapped FEK encoding.")
        }

        let sections = try parseNoteFile(blobData)
        return SharedNote(
            noteID: responseNoteID,
            metadata: sections.metadata,
            recipientWrappedFEK: recipientWrappedFEK,
            encryptedPayload: sections.encryptedPayload
        )
    }

    public func deleteSharedNote(noteID: UUID) async throws {
        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.deleteSharedNote(noteID: noteID, accessToken: accessToken)
    }
}
