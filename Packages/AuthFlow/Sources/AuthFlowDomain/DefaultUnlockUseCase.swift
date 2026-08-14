import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import NetworkProtocol
import NoteRepositoryProtocol

@MainActor
public final class DefaultUnlockUseCase: UnlockUseCase {
    private let credentialStore: any CredentialStore
    private let vaultAuthenticator: any VaultAuthenticator
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let establishVaultSession: any EstablishVaultSessionUseCase
    private let restoreOnlineSession: any RestoreOnlineSessionUseCase
    private let sessionPasswordCache: any SessionPasswordCaching

    public init(
        credentialStore: any CredentialStore,
        vaultAuthenticator: any VaultAuthenticator,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing,
        establishVaultSession: any EstablishVaultSessionUseCase,
        restoreOnlineSession: any RestoreOnlineSessionUseCase,
        sessionPasswordCache: any SessionPasswordCaching
    ) {
        self.credentialStore = credentialStore
        self.vaultAuthenticator = vaultAuthenticator
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.establishVaultSession = establishVaultSession
        self.restoreOnlineSession = restoreOnlineSession
        self.sessionPasswordCache = sessionPasswordCache
    }

    public func execute(password: String, email: String) async throws {
        if networkReachability.isOnline {
            do {
                try await restoreOnlineSession.execute(email: email, password: password)
            } catch let error as AuthRepositoryError {
                throw AuthFlowErrorMapper.mapUnlockAuthError(error)
            }
        }

        guard let headerData = credentialStore.vaultHeader() else {
            throw AuthFlowError.vaultNotFound
        }

        do {
            try await establishVaultSession.execute(
                headerData: headerData,
                password: password,
                policy: .standardUnlock
            )
            sessionPasswordCache.store(password)
            if networkReachability.isOnline {
                await noteSync.flushPending()
            }
        } catch let error as AuthFlowError {
            throw error
        } catch {
            throw AuthFlowError.vaultUnlockFailed
        }
    }
}
