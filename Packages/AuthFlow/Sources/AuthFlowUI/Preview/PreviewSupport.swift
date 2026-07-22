import AuthRepositoryProtocol
import AuthFlowProtocol
import CryptoKit
import Foundation
import VaultRepositoryProtocol
import VaultSessionProtocol

enum PreviewSupport {
    @MainActor
    static func makeLoginViewModel() -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: PreviewAuthRepository(),
            vaultRepository: PreviewVaultRepository(),
            vaultAuthenticator: PreviewVaultAuthenticator(),
            vaultSession: PreviewVaultSession()
        )
    }

    @MainActor
    static func makeRegisterViewModel() -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            authRepository: PreviewAuthRepository(),
            vaultRepository: PreviewVaultRepository(),
            vaultAuthenticator: PreviewVaultAuthenticator(),
            vaultSession: PreviewVaultSession()
        )
    }
}

private actor PreviewAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }
    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func logout() async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }
}

private actor PreviewVaultRepository: VaultRepository {
    func readHeader() async throws -> Data { Data() }
    func writeHeader(_ header: Data) async throws {}
    func fetchPublicKey(userID: String) async throws -> Data { Data() }
}

private struct PreviewVaultAuthenticator: VaultAuthenticator {
    func createVault(password: String) throws -> VaultCreationOutcome {
        VaultCreationOutcome(headerData: Data([0x01]), mnemonic: ["abandon"])
    }
    func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome {
        VaultUnlockOutcome(sessionKeys: VaultSessionKeys(
            udk: .init(size: .bits256),
            identityPrivateKey: Data(repeating: 0, count: 32)
        ))
    }
}

private actor PreviewVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}
