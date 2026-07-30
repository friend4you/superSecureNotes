import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation

public struct AuthSessionRestoreHelper: Sendable {
    public init() {}

    public func restoreSession(
        credentialStore: some CredentialStore,
        authRepository: some AuthRepository
    ) async throws -> AuthSession {
        guard let refreshToken = credentialStore.refreshToken() else {
            throw AuthRepositoryError.notAuthenticated
        }
        return try await authRepository.restoreSession(refreshToken: refreshToken)
    }
}
