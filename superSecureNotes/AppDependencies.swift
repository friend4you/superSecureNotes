import AuthRepository
import AuthFlowUI
import AuthRepositoryProtocol
import Foundation
import NoteRepository
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import VaultRepositoryProtocol
import VaultSession

@MainActor
final class AppDependencies {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!

    let authRepository: any AuthRepository
    let vaultRepository: any VaultRepository
    let noteRepository: any NoteRepository
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator

    init() {
        noteRepository = LocalNoteRepository()
        vaultRepository = LocalVaultRepository()
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()

        #if DEBUG
        if StubBackendConfiguration.isEnabled {
            authRepository = InMemoryAuthRepository()
            return
        }
        #endif

        authRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
    }
}
