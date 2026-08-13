import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import NetworkProtocol
import NoteRepositoryProtocol
import Observation
import VaultRepositoryProtocol
import VaultSessionProtocol

@Observable
@MainActor
public final class DefaultLoginViewModel: LoginViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle
    public private(set) var pendingBiometricEnrollment = false

    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let navigator: any Navigating
    private let credentialStore: any CredentialStore
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let sessionExpiredNotifier: SessionExpiredNotifier

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        navigator: any Navigating,
        credentialStore: any CredentialStore,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing = NoOpNoteSyncService(),
        sessionExpiredNotifier: SessionExpiredNotifier = SessionExpiredNotifier()
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.notesIndexStore = notesIndexStore
        self.navigator = navigator
        self.credentialStore = credentialStore
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.sessionExpiredNotifier = sessionExpiredNotifier
    }

    public func onAppear() {
        if sessionExpiredNotifier.consumeSessionExpiredFlag() {
            state = .failure(.sessionExpired)
        }
    }

    public func registerTapped() {
        navigator.push(AuthRoute.register)
    }

    public func makeBiometricEnrollmentViewModel() -> DefaultBiometricEnrollmentViewModel {
        DefaultBiometricEnrollmentViewModel(
            credentialStore: credentialStore,
            onComplete: { [weak self] in
                self?.pendingBiometricEnrollment = false
            }
        )
    }

    public func dismissBiometricEnrollment() {
        pendingBiometricEnrollment = false
    }

    public func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .failure(.validationError(nil))
            return
        }

        if !credentialStore.hasLocalSetup, !networkReachability.isOnline {
            state = .failure(.networkRequired)
            return
        }

        state = .loading
        let wasFirstSetup = !credentialStore.hasLocalSetup

        do {
            let session = try await authRepository.login(
                LoginCredentials(email: email, password: password)
            )
            let pulledHeader = try await noteSync.pullVaultHeaderIfLocalMissing()
            let headerData: Data
            if let pulledHeader {
                headerData = pulledHeader
            } else {
                headerData = try await vaultRepository.readHeader()
            }
            let unlockOutcome = try vaultAuthenticator.unlockVault(
                headerData: headerData,
                password: password
            )
            if pulledHeader != nil {
                try await NotesIndexStoreLifecycle.open(
                    sessionKeys: unlockOutcome.sessionKeys,
                    notesIndexStore: notesIndexStore
                )
                do {
                    try await noteSync.pullRemoteNotesCatalog()
                    try await noteSync.pullRemoteSharedCatalog()
                } catch {
                    await notesIndexStore.close()
                    throw error
                }
                await NotesIndexStoreLifecycle.establish(
                    sessionKeys: unlockOutcome.sessionKeys,
                    vaultSession: vaultSession
                )
            } else {
                try await NotesIndexStoreLifecycle.openAfterEstablish(
                    sessionKeys: unlockOutcome.sessionKeys,
                    vaultSession: vaultSession,
                    notesIndexStore: notesIndexStore
                )
            }
            try credentialStore.saveSetup(
                email: email,
                refreshToken: session.refreshToken,
                vaultHeader: headerData
            )
            pendingBiometricEnrollment = wasFirstSetup
            state = .idle
        } catch let error as AuthRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch let error as VaultRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch {
            state = .failure(.vaultUnlockFailed)
        }
    }
}
