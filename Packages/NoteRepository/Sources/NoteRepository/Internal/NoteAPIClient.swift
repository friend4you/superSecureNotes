import Foundation
import NoteRepositoryProtocol

struct NoteAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = NoteJSON.makeDecoder()
    }

    func listNotes(accessToken: String) async throws -> [NoteSummary] {
        let request = try makeAuthorizedRequest(
            path: "notes",
            method: "GET",
            accessToken: accessToken
        )
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
        let request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func writeNote(
        noteID: UUID,
        data: Data,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> NoteUploadResult {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())",
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
            throw NoteRepositoryError.validationError("Invalid sync state in upload response.")
        }
        return NoteUploadResult(
            syncState: syncState,
            updatedAt: response.updatedAt,
            etag: response.etag
        )
    }

    func initUpload(
        noteID: UUID,
        totalSize: Int,
        accessToken: String
    ) async throws -> NoteUploadSession {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/uploads",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["totalSize": totalSize])
        let responseData = try await perform(request, expectedSuccessCodes: [200, 201])
        let response = try decoder.decode(NoteUploadInitResponseDTO.self, from: responseData)
        guard let uploadID = UUID(uuidString: response.uploadId) else {
            throw NoteRepositoryError.validationError("Invalid upload ID in init response.")
        }
        return NoteUploadSession(
            uploadID: uploadID,
            chunkSize: response.chunkSize,
            totalChunks: response.totalChunks
        )
    }

    func uploadChunk(
        noteID: UUID,
        uploadID: UUID,
        chunkIndex: Int,
        data: Data,
        accessToken: String
    ) async throws {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/chunks/\(chunkIndex)",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func completeUpload(
        noteID: UUID,
        uploadID: UUID,
        accessToken: String,
        ifMatch etag: String? = nil
    ) async throws -> NoteUploadResult {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())/uploads/\(uploadID.uuidString.lowercased())/complete",
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
        let response = try decoder.decode(NoteWriteResponseDTO.self, from: responseData)
        guard let syncState = NoteSyncState(rawValue: response.syncState) else {
            throw NoteRepositoryError.validationError("Invalid sync state in upload response.")
        }
        return NoteUploadResult(
            syncState: syncState,
            updatedAt: response.updatedAt,
            etag: response.etag
        )
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
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NoteRepositoryError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NoteRepositoryError.networkError
        }

        let statusCode = httpResponse.statusCode
        if expectedSuccessCodes.contains(statusCode) {
            return data
        }

        throw mapError(statusCode: statusCode, data: data)
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
