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
        let localNotes = LocalNoteRepository(notesIndexStore: notesIndexStore)
        localNoteRepository = localNotes
        noteRepository = localNotes
        localVaultRepository = LocalVaultRepository()
        vaultRepository = localVaultRepository
        let session = VaultSession()
        vaultSession = session
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
            localNotes: localNotes,
            remoteNotes: networkNoteRepository,
            localVault: localVaultRepository,
            remoteVault: networkVaultRepository,
            noteFEKProvider: { noteID in
                guard await session.isActive else {
                    return nil
                }
                let udk = try await session.udk()
                let note = try await localNotes.readNote(noteID: noteID)
                return try unwrapFEK(note.wrappedFEK, with: udk)
            }
        )
    }
}
