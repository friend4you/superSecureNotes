import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import NetworkProtocol
import NoteRepositoryProtocol
import VaultRepositoryProtocol

@MainActor
public final class DefaultRegisterUseCase: RegisterUseCase {
    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let credentialStore: any CredentialStore
    private let networkReachability: any NetworkReachability
    private let noteSync: any NoteSyncing
    private let establishVaultSession: any EstablishVaultSessionUseCase
    private let sessionPasswordCache: any SessionPasswordCaching

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        credentialStore: any CredentialStore,
        networkReachability: any NetworkReachability,
        noteSync: any NoteSyncing,
        establishVaultSession: any EstablishVaultSessionUseCase,
        sessionPasswordCache: any SessionPasswordCaching
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.credentialStore = credentialStore
        self.networkReachability = networkReachability
        self.noteSync = noteSync
        self.establishVaultSession = establishVaultSession
        self.sessionPasswordCache = sessionPasswordCache
    }

    public func execute(email: String, password: String) async throws -> RegisterResult {
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthFlowError.validationError(nil)
        }

        if !credentialStore.hasLocalSetup, !networkReachability.isOnline {
            throw AuthFlowError.networkRequired
        }

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
            try await establishVaultSession.execute(
                headerData: creationOutcome.headerData,
                password: password,
                policy: .afterLocalCreate
            )
            try credentialStore.saveSetup(
                email: email,
                refreshToken: session.refreshToken,
                vaultHeader: creationOutcome.headerData
            )
            sessionPasswordCache.store(password)
            return RegisterResult(wasFirstSetup: wasFirstSetup)
        } catch let error as AuthFlowError {
            throw error
        } catch let error as AuthRepositoryError {
            throw AuthFlowErrorMapper.map(error)
        } catch let error as VaultRepositoryError {
            throw AuthFlowErrorMapper.map(error)
        } catch {
            throw AuthFlowError.networkError
        }
    }
}
