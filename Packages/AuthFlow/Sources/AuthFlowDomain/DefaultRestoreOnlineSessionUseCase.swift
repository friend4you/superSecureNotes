import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol

@MainActor
public final class DefaultRestoreOnlineSessionUseCase: RestoreOnlineSessionUseCase {
    private let credentialStore: any CredentialStore
    private let authRepository: any AuthRepository

    public init(
        credentialStore: any CredentialStore,
        authRepository: any AuthRepository
    ) {
        self.credentialStore = credentialStore
        self.authRepository = authRepository
    }

    public func execute(email: String, password: String) async throws {
        do {
            try await restoreSession()
        } catch let error as AuthRepositoryError where error == .networkError {
            return
        } catch {
            try await retryLogin(email: email, password: password)
        }
    }

    private func restoreSession() async throws {
        guard let refreshToken = credentialStore.refreshToken() else {
            throw AuthRepositoryError.notAuthenticated
        }
        let session = try await authRepository.restoreSession(refreshToken: refreshToken)
        try credentialStore.saveRefreshToken(session.refreshToken)
    }

    private func retryLogin(email: String, password: String) async throws {
        do {
            _ = try await authRepository.login(
                LoginCredentials(email: email, password: password)
            )
        } catch let error as AuthRepositoryError where error == .networkError {
            return
        }
    }
}
