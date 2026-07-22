import Foundation
import VaultRepositoryProtocol

struct VaultAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = VaultJSON.makeDecoder()
    }

    func readHeader(accessToken: String) async throws -> Data {
        let request = try makeAuthorizedRequest(
            path: "vault/header",
            method: "GET",
            accessToken: accessToken
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func writeHeader(_ header: Data, accessToken: String) async throws {
        var request = try makeAuthorizedRequest(
            path: "vault/header",
            method: "PUT",
            accessToken: accessToken
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = header
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func fetchPublicKey(userID: String, accessToken: String) async throws -> Data {
        let request = try makeAuthorizedRequest(
            path: "users/\(userID)/public-key",
            method: "GET",
            accessToken: accessToken
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        let response = try decoder.decode(PublicKeyResponseDTO.self, from: data)
        guard let publicKeyData = Data(base64Encoded: response.publicKey) else {
            throw VaultRepositoryError.validationError("Invalid public key encoding.")
        }
        return publicKeyData
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
            throw VaultRepositoryError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VaultRepositoryError.networkError
        }

        let statusCode = httpResponse.statusCode
        if expectedSuccessCodes.contains(statusCode) {
            return data
        }

        throw mapError(statusCode: statusCode, data: data)
    }

    private func mapError(statusCode: Int, data: Data) -> VaultRepositoryError {
        if let errorResponse = try? decoder.decode(ErrorResponseDTO.self, from: data) {
            switch errorResponse.error {
            case "unauthorized":
                return .notAuthenticated
            case "header_not_found":
                return .headerNotFound
            case "public_key_not_found":
                return .publicKeyNotFound
            case "validation_error":
                return .validationError(errorResponse.message)
            default:
                break
            }
        }

        return .serverError(statusCode: statusCode)
    }
}
