import AuthRepository
import AuthFlowUI
import AuthRepositoryProtocol
import CredentialStore
import Foundation
import NetworkMonitoring
import NoteRepository
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepository
import VaultRepositoryProtocol
import VaultSession

@MainActor
final class AppDependencies {
    static let apiBaseURL = URL(string: "https://api.example.com/v1")!

    let notesIndexStore: NotesIndexStore
    let noteRepository: any NoteRepository
    let vaultRepository: any VaultRepository
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator
    let credentialStore: KeychainCredentialStore
    let biometricAuthenticator: LocalAuthenticationBiometricAuthenticator
    let networkReachability: NWPathNetworkReachability
    let authRepository: any AuthRepository

    init() {
        notesIndexStore = NotesIndexStore()
        noteRepository = LocalNoteRepository(notesIndexStore: notesIndexStore)
        vaultRepository = LocalVaultRepository()
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()
        credentialStore = KeychainCredentialStore()
        biometricAuthenticator = LocalAuthenticationBiometricAuthenticator()
        networkReachability = NWPathNetworkReachability()

        #if DEBUG
        if StubBackendConfiguration.isEnabled {
            authRepository = InMemoryAuthRepository()
            return
        }
        #endif

        authRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
    }
}
