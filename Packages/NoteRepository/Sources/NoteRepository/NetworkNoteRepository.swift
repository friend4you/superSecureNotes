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
        let refreshAccessToken = Self.makeRefreshHandler(from: tokenProvider)
        self.apiClient = NoteAPIClient(
            baseURL: baseURL,
            session: session,
            refreshAccessToken: refreshAccessToken
        )
        self.tokenProvider = tokenProvider
    }

    init(apiClient: NoteAPIClient, tokenProvider: any AccessTokenProviding) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    private static func makeRefreshHandler(
        from tokenProvider: any AccessTokenProviding
    ) -> (@Sendable () async throws -> String)? {
        guard let refreshing = tokenProvider as? any AccessTokenRefreshing else {
            return nil
        }
        return { try await refreshing.refreshAccessToken() }
    }

    public func listNotes() async throws -> [NoteSummary] {
        try await listNotes(includeDeleted: false)
    }

    func listNotes(includeDeleted: Bool) async throws -> [NoteSummary] {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.listNotes(accessToken: accessToken, includeDeleted: includeDeleted)
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
        let summary = try await attachmentSummary(noteID: noteID, attachmentID: attachmentID, shared: false)
        return try await downloadAttachmentChunks(
            noteID: noteID,
            summary: summary,
            shared: false,
            onBytesReceived: nil
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

    func readAttachment(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        onBytesReceived: (@Sendable (UInt64) -> Void)?
    ) async throws -> Data {
        try await downloadAttachmentChunks(
            noteID: noteID,
            summary: summary,
            shared: false,
            onBytesReceived: onBytesReceived
        )
    }

    func readSharedAttachment(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        onBytesReceived: (@Sendable (UInt64) -> Void)?
    ) async throws -> Data {
        try await downloadAttachmentChunks(
            noteID: noteID,
            summary: summary,
            shared: true,
            onBytesReceived: onBytesReceived
        )
    }

    func readSharedAttachment(noteID: UUID, attachmentID: UUID) async throws -> Data {
        let summary = try await attachmentSummary(noteID: noteID, attachmentID: attachmentID, shared: true)
        return try await downloadAttachmentChunks(
            noteID: noteID,
            summary: summary,
            shared: true,
            onBytesReceived: nil
        )
    }

    private func attachmentSummary(
        noteID: UUID,
        attachmentID: UUID,
        shared: Bool
    ) async throws -> RemoteAttachmentSummary {
        let attachments: [RemoteAttachmentSummary]
        if shared {
            attachments = try await listSharedAttachments(noteID: noteID)
        } else {
            attachments = try await listAttachments(noteID: noteID)
        }
        guard let summary = attachments.first(where: { $0.attachmentID == attachmentID }) else {
            throw NoteRepositoryError.noteNotFound
        }
        return summary
    }

    private func downloadAttachmentChunks(
        noteID: UUID,
        summary: RemoteAttachmentSummary,
        shared: Bool,
        onBytesReceived: (@Sendable (UInt64) -> Void)?
    ) async throws -> Data {
        guard summary.totalChunks > 0 else {
            throw NoteRepositoryError.validationError("Attachment manifest totalChunks must be greater than zero.")
        }
        let accessToken = try await tokenProvider.accessToken()
        var concatenated = Data()
        concatenated.reserveCapacity(Int(summary.sizeBytes))
        var bytesReceived: UInt64 = 0
        for chunkIndex in 0 ..< summary.totalChunks {
            let chunk: Data
            if shared {
                chunk = try await apiClient.readSharedAttachmentChunk(
                    noteID: noteID,
                    attachmentID: summary.attachmentID,
                    chunkIndex: chunkIndex,
                    accessToken: accessToken
                )
            } else {
                chunk = try await apiClient.readAttachmentChunk(
                    noteID: noteID,
                    attachmentID: summary.attachmentID,
                    chunkIndex: chunkIndex,
                    accessToken: accessToken
                )
            }
            concatenated.append(chunk)
            bytesReceived += UInt64(chunk.count)
            onBytesReceived?(bytesReceived)
        }
        return concatenated
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

        let metadata = note.metadata.withStoredAttachmentManifest(note.attachmentCiphertexts)
        let finalBodyData = try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: note.wrappedFEK,
            encryptedPayload: note.encryptedPayload
        )
        let accessToken = try await tokenProvider.accessToken()
        let noteID = metadata.noteID
        let hasAttachments = !note.attachmentCiphertexts.isEmpty
        let noteExistsOnServer = try await noteExistsOnServer(noteID: noteID, accessToken: accessToken)
        var bodyIfMatch = etag

        if !noteExistsOnServer, hasAttachments {
            let bootstrapBodyData = try assembleNoteFile(
                metadata: metadata.withZeroAttachmentManifest(),
                wrappedFEK: note.wrappedFEK,
                encryptedPayload: note.encryptedPayload
            )
            let bootstrapResult = try await apiClient.writeBody(
                noteID: noteID,
                data: bootstrapBodyData,
                accessToken: accessToken,
                ifMatch: nil
            )
            bodyIfMatch = bootstrapResult.etag ?? bodyIfMatch
        } else if noteExistsOnServer {
            try await deleteRemovedAttachments(
                noteID: noteID,
                localAttachmentIDs: Set(note.attachmentCiphertexts.keys),
                accessToken: accessToken
            )
        }

        var result = NoteUploadResult(syncState: .pendingSync, updatedAt: metadata.updatedAt, etag: nil)
        let attachmentEntries = note.attachmentCiphertexts.sorted {
            $0.key.uuidString.lowercased() < $1.key.uuidString.lowercased()
        }
        for (attachmentID, ciphertext) in attachmentEntries {
            let attachmentResult = try await uploadAttachment(
                noteID: noteID,
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

        let bodyResult = try await apiClient.writeBody(
            noteID: noteID,
            data: finalBodyData,
            accessToken: accessToken,
            ifMatch: bodyIfMatch
        )
        return NoteUploadResult(
            syncState: bodyResult.syncState,
            updatedAt: bodyResult.updatedAt,
            etag: bodyResult.etag ?? result.etag
        )
    }

    private func noteExistsOnServer(noteID: UUID, accessToken: String) async throws -> Bool {
        do {
            _ = try await apiClient.listAttachments(noteID: noteID, accessToken: accessToken)
            return true
        } catch NoteRepositoryError.noteNotFound {
            return false
        }
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
        try await uploadAttachmentChunked(
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
