import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NetworkProtocol
import NoteRepositoryProtocol
import Observation
import VaultSessionProtocol

@Observable
@MainActor
public final class DefaultUnlockViewModel: UnlockViewModel {
    public private(set) var email: String
    public var password = ""
    public private(set) var state: UnlockFormState = .awaitingPresence

    private let credentialStore: any CredentialStore
    private let authRepository: any AuthRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let biometricAuthenticator: any BiometricAuthenticator
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let performLogout: () async -> Void

    public init(
        credentialStore: any CredentialStore,
        authRepository: any AuthRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        biometricAuthenticator: any BiometricAuthenticator,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing = NoOpNoteSyncService(),
        performLogout: @escaping () async -> Void = {}
    ) {
        self.credentialStore = credentialStore
        self.authRepository = authRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.notesIndexStore = notesIndexStore
        self.biometricAuthenticator = biometricAuthenticator
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.performLogout = performLogout
        self.email = credentialStore.email() ?? ""
    }

    public func onAppear() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func retryBiometrics() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func logout() async {
        await performLogout()
    }

    public func unlockWithPassword() async {
        guard !password.isEmpty else {
            state = .failure(.validationError(nil))
            return
        }
        await performUnlock(using: password)
    }

    private func attemptBiometricUnlockIfEnabled() async {
        guard credentialStore.bioEnabled(), biometricAuthenticator.canEvaluateBiometrics() else {
            state = .passwordEntry
            return
        }

        state = .awaitingPresence
        let result = await biometricAuthenticator.authenticate(
            reason: "Unlock your vault"
        )

        switch result {
        case .success:
            do {
                let retrievedPassword = try credentialStore.loadPasswordWithBiometrics()
                await performUnlock(using: retrievedPassword)
            } catch {
                state = .passwordEntry
            }
        case .cancelled, .failed, .unavailable:
            state = .passwordEntry
        }
    }

    private func performUnlock(using unlockPassword: String) async {
        state = .loading

        do {
            if networkReachability.isOnline {
                try await restoreOnlineSession(using: unlockPassword)
            }
            try await unlockVault(using: unlockPassword)
            state = .idle
            password = ""
        } catch let error as AuthRepositoryError {
            state = .failure(mapAuthError(error))
        } catch {
            state = .failure(.vaultUnlockFailed)
        }
    }

    private func restoreOnlineSession(using unlockPassword: String) async throws {
        let restoreHelper = AuthSessionRestoreHelper()

        do {
            _ = try await restoreHelper.restoreSession(
                credentialStore: credentialStore,
                authRepository: authRepository
            )
        } catch let error as AuthRepositoryError where error == .networkError {
            return
        } catch {
            try await retryLoginAfterRestoreFailure(using: unlockPassword)
        }
    }

    private func retryLoginAfterRestoreFailure(using unlockPassword: String) async throws {
        do {
            _ = try await authRepository.login(
                LoginCredentials(email: email, password: unlockPassword)
            )
        } catch let error as AuthRepositoryError where error == .networkError {
            return
        }
    }

    private func unlockVault(using unlockPassword: String) async throws {
        guard let headerData = credentialStore.vaultHeader() else {
            throw AuthFlowError.vaultNotFound
        }

        let unlockOutcome = try vaultAuthenticator.unlockVault(
            headerData: headerData,
            password: unlockPassword
        )
        try await NotesIndexStoreLifecycle.openAfterEstablish(
            sessionKeys: unlockOutcome.sessionKeys,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )
        if networkReachability.isOnline {
            await noteSync.flushPending()
        }
    }

    private func mapAuthError(_ error: AuthRepositoryError) -> AuthFlowError {
        switch error {
        case .invalidCredentials:
            return .sessionExpired
        case .networkError:
            return .networkError
        case let .validationError(message):
            return .validationError(message)
        case let .serverError(_, message):
            return message.map(AuthFlowError.validationError) ?? .unknown
        case .emailAlreadyExists, .notAuthenticated:
            return .unknown
        }
    }
}
