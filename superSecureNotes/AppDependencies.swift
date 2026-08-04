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
    static let apiBaseURL = URL(string: "http://localhost:8000/v1")!

    let notesIndexStore: NotesIndexStore
    let localNoteRepository: LocalNoteRepository
    let noteRepository: any NoteRepository
    let localVaultRepository: LocalVaultRepository
    let vaultRepository: any VaultRepository
    let networkVaultRepository: NetworkVaultRepository
    let networkNoteRepository: NetworkNoteRepository
    let noteSyncService: LocalFirstNoteSyncService
    let vaultSession: VaultSession
    let vaultAuthenticator: SecureCryptoVaultAuthenticator
    let credentialStore: KeychainCredentialStore
    let biometricAuthenticator: LocalAuthenticationBiometricAuthenticator
    let networkReachability: NWPathNetworkReachability
    let authRepository: any AuthRepository

    init() {
        notesIndexStore = NotesIndexStore()
        localNoteRepository = LocalNoteRepository(notesIndexStore: notesIndexStore)
        noteRepository = localNoteRepository
        localVaultRepository = LocalVaultRepository()
        vaultRepository = localVaultRepository
        vaultSession = VaultSession()
        vaultAuthenticator = SecureCryptoVaultAuthenticator()
        credentialStore = KeychainCredentialStore()
        biometricAuthenticator = LocalAuthenticationBiometricAuthenticator()
        networkReachability = NWPathNetworkReachability()

        authRepository = NetworkAuthRepository(baseURL: Self.apiBaseURL)
        let tokenProvider = AuthRepositoryAccessTokenProvider(repository: authRepository)
        let vaultAPIClient = VaultAPIClient(
            baseURL: Self.apiBaseURL,
            tokenProvider: tokenProvider
        )
        networkVaultRepository = NetworkVaultRepository(apiClient: vaultAPIClient)
        networkNoteRepository = NetworkNoteRepository(
            baseURL: Self.apiBaseURL,
            tokenProvider: tokenProvider
        )
        noteSyncService = LocalFirstNoteSyncService(
            localNotes: localNoteRepository,
            remoteNotes: networkNoteRepository,
            localVault: localVaultRepository,
            remoteVault: networkVaultRepository
        )
    }
}
