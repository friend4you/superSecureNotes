import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import VaultRepositoryProtocol

public struct AuthRepositoryAccessTokenProvider: AccessTokenRefreshing {
    private let repository: any AuthRepository
    private let credentialStore: any CredentialStore
    private let onSessionExpired: (@Sendable () async -> Void)?

    public init(
        repository: any AuthRepository,
        credentialStore: any CredentialStore,
        onSessionExpired: (@Sendable () async -> Void)? = nil
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.onSessionExpired = onSessionExpired
    }

    public func accessToken() async throws -> String {
        guard let session = await repository.currentSession else {
            throw VaultRepositoryError.notAuthenticated
        }
        return session.accessToken
    }

    public func refreshAccessToken() async throws -> String {
        do {
            let session = try await repository.refreshSession()
            try credentialStore.saveRefreshToken(session.refreshToken)
            return session.accessToken
        } catch let error as AuthRepositoryError where error == .notAuthenticated {
            if let onSessionExpired {
                await onSessionExpired()
            }
            throw VaultRepositoryError.notAuthenticated
        }
    }
}
