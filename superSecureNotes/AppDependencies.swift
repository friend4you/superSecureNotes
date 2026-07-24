import AuthRepository
import AuthFlowUI
import Foundation
import SecureCrypto
import VaultRepository
import VaultSession

@MainActor
final class AppDependencies {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!

    let authRepository: NetworkAuthRepository
    let vaultRepository: NetworkVaultRepository
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator

    init() {
        authRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
        let tokenProvider = AuthRepositoryAccessTokenProvider(repository: authRepository)
        vaultRepository = NetworkVaultRepository(
            baseURL: Self.apiBaseURL,
            tokenProvider: tokenProvider
        )
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()
    }
}
