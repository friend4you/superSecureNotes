import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStoreProtocol
import NavigationProtocol
import NetworkProtocol
import NoteRepositoryProtocol
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
public final class AuthFlowDependencies: AuthFlowDependencyProviding {
    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let navigator: any Navigating
    private let credentialStore: any CredentialStore
    private let biometricAuthenticator: any BiometricAuthenticator
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let vaultHeaderUploader: any VaultHeaderUploadScheduling

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        navigator: any Navigating,
        credentialStore: any CredentialStore,
        biometricAuthenticator: any BiometricAuthenticator,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing = NoOpNoteSyncService(),
        vaultHeaderUploader: any VaultHeaderUploadScheduling = NoOpVaultHeaderUploadScheduler()
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.notesIndexStore = notesIndexStore
        self.navigator = navigator
        self.credentialStore = credentialStore
        self.biometricAuthenticator = biometricAuthenticator
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.vaultHeaderUploader = vaultHeaderUploader
    }

    public func makeLoginViewModel() -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            navigator: navigator,
            credentialStore: credentialStore,
            networkReachability: networkReachability
        )
    }

    public func makeRegisterViewModel() -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            vaultHeaderUploader: vaultHeaderUploader
        )
    }

    public func makeUnlockViewModel() -> DefaultUnlockViewModel {
        DefaultUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            biometricAuthenticator: biometricAuthenticator,
            networkReachability: networkReachability,
            noteSync: noteSync
        )
    }

    public func makeBiometricEnrollmentViewModel(
        onComplete: @escaping () -> Void
    ) -> DefaultBiometricEnrollmentViewModel {
        DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            onComplete: onComplete
        )
    }

    public func makeBiometricSettingsViewModel() -> DefaultBiometricSettingsViewModel {
        DefaultBiometricSettingsViewModel(credentialStore: credentialStore)
    }
}
