import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
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
    private let biometricAuthenticator: any BiometricAuthenticator
    private let networkReachability: any NetworkReachability

    public init(
        credentialStore: any CredentialStore,
        authRepository: any AuthRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        biometricAuthenticator: any BiometricAuthenticator,
        networkReachability: any NetworkReachability
    ) {
        self.credentialStore = credentialStore
        self.authRepository = authRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.biometricAuthenticator = biometricAuthenticator
        self.networkReachability = networkReachability
        self.email = credentialStore.email() ?? ""
    }

    public func onAppear() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func retryBiometrics() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func unlockWithPassword() async {
        guard !password.isEmpty else {
            state = .failure(.validationError)
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
        } catch {
            _ = try await authRepository.login(
                LoginCredentials(email: email, password: unlockPassword)
            )
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
        await vaultSession.establish(unlockOutcome.sessionKeys)
    }

    private func mapAuthError(_ error: AuthRepositoryError) -> AuthFlowError {
        switch error {
        case .invalidCredentials:
            return .sessionExpired
        case .networkError:
            return .networkError
        case .validationError:
            return .validationError
        case .emailAlreadyExists, .notAuthenticated, .serverError:
            return .unknown
        }
    }
}
