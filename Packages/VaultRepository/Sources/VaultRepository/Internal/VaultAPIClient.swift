import Foundation
import VaultRepositoryProtocol

public struct VaultAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: any AccessTokenProviding
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        tokenProvider: any AccessTokenProviding,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = VaultJSON.makeDecoder()
    }

    func readHeader() async throws -> Data {
        let request = try await makeAuthorizedRequest(
            path: "vault/header",
            method: "GET"
        )
        return try await perform(request, expectedSuccessCodes: [200])
    }

    func writeHeader(_ header: Data) async throws {
        var request = try await makeAuthorizedRequest(
            path: "vault/header",
            method: "PUT"
        )
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = header
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func fetchPublicKey(email: String) async throws -> Data {
        let request = try await makeAuthorizedRequest(
            path: "users/public-key",
            method: "GET",
            queryItems: [URLQueryItem(name: "email", value: email)]
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try decodePublicKey(from: data)
    }

    private func decodePublicKey(from data: Data) throws -> Data {
        let response = try decoder.decode(PublicKeyResponseDTO.self, from: data)
        guard let publicKeyData = Data(base64Encoded: response.publicKey) else {
            throw VaultRepositoryError.validationError("Invalid public key encoding.")
        }
        return publicKeyData
    }

    private func makeAuthorizedRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> URLRequest {
        let accessToken = try await tokenProvider.accessToken()
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw VaultRepositoryError.validationError("Invalid request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest, expectedSuccessCodes: Set<Int>) async throws -> Data {
        let refreshHandler = Self.makeRefreshHandler(from: tokenProvider)
        return try await AuthorizedHTTPPerform.data(
            for: request,
            session: session,
            expectedSuccessCodes: expectedSuccessCodes,
            refreshAccessToken: refreshHandler,
            mapTransportError: { VaultRepositoryError.networkError },
            mapHTTPError: mapError
        )
    }

    private static func makeRefreshHandler(
        from tokenProvider: any AccessTokenProviding
    ) -> (@Sendable () async throws -> String)? {
        guard let refreshing = tokenProvider as? any AccessTokenRefreshing else {
            return nil
        }
        return { try await refreshing.refreshAccessToken() }
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
            case "user_not_found":
                return .userNotFound(errorResponse.message)
            case "validation_error":
                return .validationError(errorResponse.message)
            default:
                return .serverError(statusCode: statusCode, message: errorResponse.message)
            }
        }

        return .serverError(statusCode: statusCode, message: nil)
    }
}
