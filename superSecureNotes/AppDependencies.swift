import AuthRepository
import AuthFlowUI
import AuthRepositoryProtocol
import Foundation
import SecureCrypto
import VaultRepository
import VaultRepositoryProtocol
import VaultSession

@MainActor
final class AppDependencies {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!

    let authRepository: any AuthRepository
    let vaultRepository: any VaultRepository
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator

    init() {
        #if DEBUG
        if StubBackendConfiguration.isEnabled {
            authRepository = InMemoryAuthRepository()
            vaultRepository = FileVaultRepository()
            vaultSession = VaultSession()
            vaultAuthenticator = SecureCryptoVaultAuthenticator()
            return
        }
        #endif

        let networkAuthRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
        authRepository = networkAuthRepository
        let tokenProvider = AuthRepositoryAccessTokenProvider(repository: networkAuthRepository)
        vaultRepository = NetworkVaultRepository(
            baseURL: Self.apiBaseURL,
            tokenProvider: tokenProvider
        )
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()
    }
}
