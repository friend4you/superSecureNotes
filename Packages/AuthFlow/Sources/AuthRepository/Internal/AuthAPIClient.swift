import AuthRepositoryProtocol
import Foundation

struct AuthAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = AuthJSON.makeDecoder()
        self.encoder = AuthJSON.makeEncoder()
    }

    func register(email: String, password: String) async throws -> AuthAPIResult {
        let request = try makeRequest(
            path: "auth/register",
            method: "POST",
            body: CredentialsRequest(email: email, password: password)
        )
        let data = try await perform(request, expectedSuccessCodes: [201])
        return try parseAuthSuccess(data)
    }

    func login(email: String, password: String) async throws -> AuthAPIResult {
        let request = try makeRequest(
            path: "auth/login",
            method: "POST",
            body: CredentialsRequest(email: email, password: password)
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        return try parseAuthSuccess(data)
    }

    func logout(accessToken: String) async throws {
        var request = try makeRequest(path: "auth/logout", method: "POST", body: EmptyBody())
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await perform(request, expectedSuccessCodes: [204])
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        let request = try makeRequest(
            path: "auth/refresh",
            method: "POST",
            body: RefreshRequest(refreshToken: refreshToken)
        )
        let data = try await perform(request, expectedSuccessCodes: [200])
        let response = try decoder.decode(RefreshResponseDTO.self, from: data)
        return makeSession(from: response)
    }

    private struct EmptyBody: Encodable {}

    private func makeRequest<B: Encodable>(
        path: String,
        method: String,
        body: B
    ) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func perform(_ request: URLRequest, expectedSuccessCodes: Set<Int>) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthRepositoryError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthRepositoryError.networkError
        }

        let statusCode = httpResponse.statusCode
        if expectedSuccessCodes.contains(statusCode) {
            return data
        }

        throw mapError(statusCode: statusCode, data: data)
    }

    private func parseAuthSuccess(_ data: Data) throws -> AuthAPIResult {
        let response = try decoder.decode(AuthSuccessResponseDTO.self, from: data)
        return AuthAPIResult(
            user: response.user.toUser(),
            session: makeSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresIn: response.expiresIn
            )
        )
    }

    private func makeSession(from response: RefreshResponseDTO) -> AuthSession {
        makeSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )
    }

    private func makeSession(accessToken: String, refreshToken: String, expiresIn: Int) -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    private func mapError(statusCode: Int, data: Data) -> AuthRepositoryError {
        if let errorResponse = try? decoder.decode(ErrorResponseDTO.self, from: data) {
            switch errorResponse.error {
            case "invalid_credentials":
                return .invalidCredentials
            case "email_already_exists":
                return .emailAlreadyExists
            case "validation_error":
                return .validationError(errorResponse.message)
            case "unauthorized":
                return .notAuthenticated
            default:
                return .serverError(statusCode: statusCode, message: errorResponse.message)
            }
        }

        return .serverError(statusCode: statusCode, message: nil)
    }
}
