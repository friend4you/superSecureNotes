import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import Foundation
import NetworkProtocol
import NoteRepositoryProtocol
import VaultRepositoryProtocol

@MainActor
public final class DefaultLoginUseCase: LoginUseCase {
    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let credentialStore: any CredentialStore
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let establishVaultSession: any EstablishVaultSessionUseCase

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        credentialStore: any CredentialStore,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing,
        establishVaultSession: any EstablishVaultSessionUseCase
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.credentialStore = credentialStore
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.establishVaultSession = establishVaultSession
    }

    public func execute(email: String, password: String) async throws -> LoginResult {
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthFlowError.validationError(nil)
        }

        if !credentialStore.hasLocalSetup, !networkReachability.isOnline {
            throw AuthFlowError.networkRequired
        }

        let wasFirstSetup = !credentialStore.hasLocalSetup

        do {
            let session = try await authRepository.login(
                LoginCredentials(email: email, password: password)
            )
            let pulledHeader = try await noteSync.pullVaultHeaderIfLocalMissing()
            let headerData: Data
            let policy: EstablishVaultSessionPolicy
            if let pulledHeader {
                headerData = pulledHeader
                policy = .firstLoginWithRemoteHeader
            } else {
                headerData = try await vaultRepository.readHeader()
                policy = .standardUnlock
            }
            try await establishVaultSession.execute(
                headerData: headerData,
                password: password,
                policy: policy
            )
            try credentialStore.saveSetup(
                email: email,
                refreshToken: session.refreshToken,
                vaultHeader: headerData
            )
            return LoginResult(wasFirstSetup: wasFirstSetup)
        } catch let error as AuthFlowError {
            throw error
        } catch let error as AuthRepositoryError {
            throw AuthFlowErrorMapper.map(error)
        } catch let error as VaultRepositoryError {
            throw AuthFlowErrorMapper.map(error)
        } catch {
            throw AuthFlowError.vaultUnlockFailed
        }
    }
}
