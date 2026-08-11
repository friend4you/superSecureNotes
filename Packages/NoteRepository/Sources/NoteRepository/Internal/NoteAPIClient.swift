import Foundation
import NoteRepositoryProtocol
import VaultRepository

struct NoteAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let refreshAccessToken: (@Sendable () async throws -> String)?

    init(
        baseURL: URL,
        session: URLSession,
        refreshAccessToken: (@Sendable () async throws -> String)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = NoteJSON.makeDecoder()
        self.refreshAccessToken = refreshAccessToken
    }

    func listNotes(accessToken: String, includeDeleted: Bool = false) async throws -> [NoteSummary] {
        var url = baseURL.appending(path: "notes")
        if includeDeleted {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "includeDeleted", value: "true")]
            guard let queryURL = components.url else {
                throw NoteRepositoryError.validationError("Invalid notes list URL.")
            }
            url = queryURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request, expectedSuccessCodes: [200])
        let response = try decoder.decode([NoteSummaryResponseDTO].self, from: data)
        return try response.map { dto in
            guard let noteID = UUID(uuidString: dto.noteId) else {
                throw NoteRepositoryError.validationError("Invalid note ID in list response.")
            }
            let syncState = dto.syncState.flatMap(NoteSyncState.init(rawValue:)) ?? .synced
            return NoteSummary(
                noteID: noteID,
                title: dto.title,
                updatedAt: dto.updatedAt,
                syncState: syncState,
                etag: dto.etag
            )
        }
    }

    func readNote(noteID: UUID, accessToken: String) async throws -> Data {
        throw NoteRepositoryError.notSupported
    }

    func writeNote(
        noteID: UUID,
        data: Data,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> NoteUploadResult {
        throw NoteRepositoryError.notSupported
    }

    func readBody(noteID: UUID, accessToken: String) async throws -> Data {
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/body",
            method: "GET",
            accessToken: accessToken
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func writeBody(
        noteID: UUID,
        data: Data,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> NoteUploadResult {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/body",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        request.httpBody = data
        let responseData = try await perform(request, expectedSuccessCodes: [200, 204])
        if responseData.isEmpty {
            return NoteUploadResult(syncState: .synced, updatedAt: 0, etag: nil)
        }
        let response = try decoder.decode(NoteWriteResponseDTO.self, from: responseData)
        guard let syncState = NoteSyncState(rawValue: response.syncState) else {
            throw NoteRepositoryError.validationError("Invalid sync state in body upload response.")
        }
        return NoteUploadResult(
            syncState: syncState,
            updatedAt: response.updatedAt,
            etag: response.etag
        )
    }

    func listAttachments(noteID: UUID, accessToken: String) async throws -> [RemoteAttachmentSummary] {
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try decodeAttachmentManifest(from: data)
    }

    func readAttachment(
        noteID: UUID,
        attachmentID: UUID,
        accessToken: String
    ) async throws -> Data {
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func writeAttachment(
        noteID: UUID,
        attachmentID: UUID,
        data: Data,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> AttachmentUploadResult {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        request.httpBody = data
        let responseData = try await perform(request, expectedSuccessCodes: [200, 204])
        if responseData.isEmpty {
            return AttachmentUploadResult(etag: nil, noteEtag: nil)
        }
        let response = try decoder.decode(AttachmentWriteResponseDTO.self, from: responseData)
        return AttachmentUploadResult(etag: response.etag, noteEtag: response.noteEtag)
    }

    func deleteAttachment(
        noteID: UUID,
        attachmentID: UUID,
        accessToken: String
    ) async throws {
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())",
            method: "DELETE",
            accessToken: accessToken
        )
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func initAttachmentUpload(
        noteID: UUID,
        attachmentID: UUID,
        totalSize: Int,
        accessToken: String
    ) async throws -> NoteUploadSession {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["totalSize": totalSize])
        let responseData = try await perform(request, expectedSuccessCodes: [200, 201])
        let response = try decoder.decode(NoteUploadInitResponseDTO.self, from: responseData)
        guard let uploadID = UUID(uuidString: response.uploadId) else {
            throw NoteRepositoryError.validationError("Invalid upload ID in attachment init response.")
        }
        return NoteUploadSession(
            uploadID: uploadID,
            chunkSize: response.chunkSize,
            totalChunks: response.totalChunks
        )
    }

    func uploadAttachmentChunk(
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        chunkIndex: Int,
        data: Data,
        accessToken: String
    ) async throws {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/chunks/\(chunkIndex)",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func completeAttachmentUpload(
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> AttachmentUploadResult {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/complete",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["ifMatch": etag])
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: [:])
        }
        let responseData = try await perform(request, expectedSuccessCodes: [200])
        let response = try decoder.decode(AttachmentWriteResponseDTO.self, from: responseData)
        return AttachmentUploadResult(etag: response.etag, noteEtag: response.noteEtag)
    }

    func initUpload(
        noteID: UUID,
        totalSize: Int,
        accessToken: String
    ) async throws -> NoteUploadSession {
        throw NoteRepositoryError.notSupported
    }

    func uploadChunk(
        noteID: UUID,
        uploadID: UUID,
        chunkIndex: Int,
        data: Data,
        accessToken: String
    ) async throws {
        throw NoteRepositoryError.notSupported
    }

    func completeUpload(
        noteID: UUID,
        uploadID: UUID,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> NoteUploadResult {
        throw NoteRepositoryError.notSupported
    }

    func deleteNote(noteID: UUID, accessToken: String) async throws {
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())",
            method: "DELETE",
            accessToken: accessToken
        )
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func listSharedNotes(accessToken: String) async throws -> [SharedNoteSummary] {
        let request = try makeAuthorizedRequest(
            path: "notes/shared",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        let response = try decoder.decode([SharedNoteSummaryResponseDTO].self, from: data)
        return try response.map { dto in
            guard let noteID = UUID(uuidString: dto.noteId) else {
                throw NoteRepositoryError.validationError("Invalid note ID in shared list response.")
            }
            guard let ownerID = UUID(uuidString: dto.ownerId) else {
                throw NoteRepositoryError.validationError("Invalid owner ID in shared list response.")
            }
            return SharedNoteSummary(
                noteID: noteID,
                title: dto.title,
                updatedAt: dto.updatedAt,
                etag: dto.etag,
                ownerEmail: dto.ownerEmail,
                ownerID: ownerID,
                sharedAt: dto.sharedAt
            )
        }
    }

    func readSharedNote(noteID: UUID, accessToken: String) async throws -> SharedNoteDownloadResponseDTO {
        let request = try makeAuthorizedRequest(
            path: "notes/shared/\(noteID.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try decoder.decode(SharedNoteDownloadResponseDTO.self, from: data)
    }

    func readSharedBody(noteID: UUID, accessToken: String) async throws -> SharedNoteBodyResponseDTO {
        let request = try makeAuthorizedRequest(
            path: "notes/shared/\(noteID.uuidString.lowercased())/body",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try decoder.decode(SharedNoteBodyResponseDTO.self, from: data)
    }

    func listSharedAttachments(
        noteID: UUID,
        accessToken: String
    ) async throws -> [RemoteAttachmentSummary] {
        let request = try makeAuthorizedRequest(
            path: "notes/shared/\(noteID.uuidString.lowercased())/attachments",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try decodeAttachmentManifest(from: data)
    }

    func readSharedAttachment(
        noteID: UUID,
        attachmentID: UUID,
        accessToken: String
    ) async throws -> Data {
        let request = try makeAuthorizedRequest(
            path: "notes/shared/\(noteID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func deleteSharedNote(noteID: UUID, accessToken: String) async throws {
        let request = try makeAuthorizedRequest(
            path: "notes/shared/\(noteID.uuidString.lowercased())",
            method: "DELETE",
            accessToken: accessToken
        )
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func shareNote(
        noteID: UUID,
        recipientEmail: String,
        wrappedFEK: Data,
        accessToken: String
    ) async throws {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/share",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "recipientEmail": recipientEmail,
            "wrappedFek": wrappedFEK.base64EncodedString(),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await perform(request, expectedSuccessCodes: [200, 201, 204])
    }

    private func decodeAttachmentManifest(from data: Data) throws -> [RemoteAttachmentSummary] {
        let response = try decoder.decode([AttachmentSummaryResponseDTO].self, from: data)
        return try response.map { dto in
            guard let attachmentID = UUID(uuidString: dto.attachmentId) else {
                throw NoteRepositoryError.validationError("Invalid attachment ID in manifest response.")
            }
            return RemoteAttachmentSummary(
                attachmentID: attachmentID,
                sizeBytes: dto.sizeBytes,
                contentType: dto.contentType ?? AttachmentManifestDefaults.contentType,
                etag: dto.etag
            )
        }
    }

    private func makeAuthorizedRequest(
        path: String,
        method: String,
        accessToken: String
    ) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest, expectedSuccessCodes: Set<Int>) async throws -> Data {
        try await AuthorizedHTTPPerform.data(
            for: request,
            session: session,
            expectedSuccessCodes: expectedSuccessCodes,
            refreshAccessToken: refreshAccessToken,
            mapTransportError: { NoteRepositoryError.networkError },
            mapHTTPError: mapError
        )
    }

    private func mapError(statusCode: Int, data: Data) -> NoteRepositoryError {
        if let errorResponse = try? decoder.decode(ErrorResponseDTO.self, from: data) {
            switch errorResponse.error {
            case "unauthorized":
                return .notAuthenticated
            case "note_not_found":
                return .noteNotFound
            case "validation_error":
                return .validationError(errorResponse.message)
            default:
                break
            }
        }

        return .serverError(statusCode: statusCode)
    }
}
