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
            return NoteSummary(noteID: noteID, title: dto.title, updatedAt: dto.updatedAt)
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

    func writeNote(noteID: UUID, data: Data, accessToken: String) async throws {
        var request = try makeAuthorizedRequest(
            path: "notes/\(noteID.uuidString.lowercased())",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await perform(request, expectedSuccessCodes: [204])
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
