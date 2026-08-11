import AuthRepositoryProtocol
import Foundation

public actor NetworkAuthRepository: AuthRepository {
    private let apiClient: AuthAPIClient
    private var session: AuthSession?
    private var user: User?
    private var inFlightRefresh: Task<AuthSession, Error>?

    public init(baseURL: URL, session: URLSession = .shared) {
        self.apiClient = AuthAPIClient(baseURL: baseURL, session: session)
    }

    init(apiClient: AuthAPIClient) {
        self.apiClient = apiClient
    }

    public var currentSession: AuthSession? {
        session
    }

    public var currentUser: User? {
        user
    }

    public func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        try validate(email: credentials.email, password: credentials.password)
        let result = try await apiClient.register(
            email: credentials.email,
            password: credentials.password
        )
        store(result)
        return result.session
    }

    public func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        try validate(email: credentials.email, password: credentials.password)
        let result = try await apiClient.login(
            email: credentials.email,
            password: credentials.password
        )
        store(result)
        return result.session
    }

    public func logout() async throws {
        if let session {
            try? await apiClient.logout(accessToken: session.accessToken)
        }
        clear()
    }

    public func refreshSession() async throws -> AuthSession {
        guard let session else {
            throw AuthRepositoryError.notAuthenticated
        }

        if let inFlightRefresh {
            return try await inFlightRefresh.value
        }

        let refreshToken = session.refreshToken
        let task = Task<AuthSession, Error> { [apiClient] in
            try await apiClient.refresh(refreshToken: refreshToken)
        }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }

        let refreshed = try await task.value
        self.session = refreshed
        return refreshed
    }

    public func restoreSession(refreshToken: String) async throws -> AuthSession {
        let refreshed = try await apiClient.refresh(refreshToken: refreshToken)
        self.session = refreshed
        return refreshed
    }

    public func clearSession() async {
        clear()
    }

    private func store(_ result: AuthAPIResult) {
        session = result.session
        user = result.user
    }

    private func clear() {
        session = nil
        user = nil
    }

    private func validate(email: String, password: String) throws {
        if email.isEmpty || password.isEmpty {
            throw AuthRepositoryError.validationError("Email and password must not be empty.")
        }
    }
}
