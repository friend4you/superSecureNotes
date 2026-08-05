import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NetworkProtocol
import NoteRepositoryProtocol
import Observation
import VaultRepositoryProtocol
import VaultSessionProtocol

@Observable
@MainActor
public final class DefaultRegisterViewModel: RegisterViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle
    public private(set) var pendingBiometricEnrollment = false

    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let credentialStore: any CredentialStore
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        credentialStore: any CredentialStore,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing = NoOpNoteSyncService()
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.notesIndexStore = notesIndexStore
        self.credentialStore = credentialStore
        self.networkReachability = networkReachability
        self.noteSync = noteSync
    }

    public func register() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .failure(.validationError)
            return
        }

        if !credentialStore.hasLocalSetup, !networkReachability.isOnline {
            state = .failure(.networkRequired)
            return
        }

        state = .loading
        let wasFirstSetup = !credentialStore.hasLocalSetup

        do {
            let session = try await authRepository.register(
                RegisterCredentials(email: email, password: password)
            )
            let creationOutcome = try vaultAuthenticator.createVault(password: password)
            try await vaultRepository.writeHeader(creationOutcome.headerData)
            do {
                try await noteSync.uploadVaultHeaderOrThrow(creationOutcome.headerData)
            } catch {
                await authRepository.clearSession()
                throw error
            }
            let unlockOutcome = try vaultAuthenticator.unlockVault(
                headerData: creationOutcome.headerData,
                password: password
            )
            try await NotesIndexStoreLifecycle.openAfterEstablish(
                sessionKeys: unlockOutcome.sessionKeys,
                vaultSession: vaultSession,
                notesIndexStore: notesIndexStore
            )
            try credentialStore.saveSetup(
                email: email,
                refreshToken: session.refreshToken,
                vaultHeader: creationOutcome.headerData
            )
            pendingBiometricEnrollment = wasFirstSetup
            state = .idle
        } catch let error as AuthRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch let error as VaultRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch {
            state = .failure(.networkError)
        }
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
}
