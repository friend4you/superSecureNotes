import AuthFlowDomain
import AuthFlowDomainProtocol
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
    private let sessionPasswordCache: any SessionPasswordCaching
    private let pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring
    private let performLogout: () async -> Void
    private let sessionExpiredNotifier: SessionExpiredNotifier
    private let syncRootRoute: () -> Void

    private lazy var establishVaultSessionUseCase: DefaultEstablishVaultSessionUseCase = {
        DefaultEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            noteSync: noteSync
        )
    }()

    private lazy var restoreOnlineSessionUseCase: DefaultRestoreOnlineSessionUseCase = {
        DefaultRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )
    }()

    private lazy var biometricUnlockUseCase: DefaultBiometricUnlockUseCase = {
        DefaultBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )
    }()

    private lazy var loginUseCase: DefaultLoginUseCase = {
        DefaultLoginUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establishVaultSessionUseCase,
            sessionPasswordCache: sessionPasswordCache
        )
    }()

    private lazy var registerUseCase: DefaultRegisterUseCase = {
        DefaultRegisterUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establishVaultSessionUseCase,
            sessionPasswordCache: sessionPasswordCache
        )
    }()

    private lazy var unlockUseCase: DefaultUnlockUseCase = {
        DefaultUnlockUseCase(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establishVaultSessionUseCase,
            restoreOnlineSession: restoreOnlineSessionUseCase,
            sessionPasswordCache: sessionPasswordCache
        )
    }()

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
        sessionPasswordCache: any SessionPasswordCaching,
        pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring = UserDefaultsPendingBiometricEnrollmentStore(),
        sessionExpiredNotifier: SessionExpiredNotifier = SessionExpiredNotifier(),
        syncRootRoute: @escaping () -> Void = {},
        performLogout: @escaping () async -> Void = {}
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
        self.sessionPasswordCache = sessionPasswordCache
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
        self.sessionExpiredNotifier = sessionExpiredNotifier
        self.syncRootRoute = syncRootRoute
        self.performLogout = performLogout
    }

    public func makeLoginViewModel() -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            loginUseCase: loginUseCase,
            credentialStore: credentialStore,
            navigator: navigator,
            sessionExpiredNotifier: sessionExpiredNotifier,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore
        )
    }

    public func makeRegisterViewModel() -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            registerUseCase: registerUseCase,
            credentialStore: credentialStore,
            navigator: navigator,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore
        )
    }

    public func makeUnlockViewModel() -> DefaultUnlockViewModel {
        DefaultUnlockViewModel(
            email: credentialStore.email() ?? "",
            unlockUseCase: unlockUseCase,
            biometricUnlockUseCase: biometricUnlockUseCase,
            navigator: navigator,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore,
            performLogout: performLogout
        )
    }

    public func makeBiometricEnrollmentViewModel() -> DefaultBiometricEnrollmentViewModel {
        DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache,
            pendingBiometricEnrollmentStore: pendingBiometricEnrollmentStore,
            navigator: navigator,
            onEnrollmentCompleted: syncRootRoute
        )
    }

    public func makeBiometricSettingsViewModel() -> DefaultBiometricSettingsViewModel {
        DefaultBiometricSettingsViewModel(
            credentialStore: credentialStore,
            sessionPasswordCache: sessionPasswordCache
        )
    }
}
