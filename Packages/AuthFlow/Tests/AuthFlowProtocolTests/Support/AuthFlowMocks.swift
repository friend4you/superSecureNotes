import AuthRepositoryProtocol
import AuthFlowProtocol
import CryptoKit
import Foundation
import VaultRepositoryProtocol
import VaultSessionProtocol
import XCTest

@testable import AuthFlowProtocol

final class AuthFlowMocksSmokeTests: XCTestCase {
    @MainActor
    func testMocksAreUsable() async throws {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()

        let viewModel = DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession,
            navigator: MockLoginNavigator()
        )

        XCTAssertEqual(viewModel.state, .idle)
    }
}

actor MockAuthRepository: AuthRepository {
    var loginCallCount = 0
    var registerCallCount = 0
    var loginError: AuthRepositoryError?
    var registerError: AuthRepositoryError?
    var shouldSuspendOnLogin = false
    var shouldSuspendOnRegister = false

    private var session: AuthSession?
    private var user: User?
    private var loginContinuation: CheckedContinuation<Void, Never>?
    private var registerContinuation: CheckedContinuation<Void, Never>?

    var currentSession: AuthSession? { session }
    var currentUser: User? { user }

    func resumeLogin() {
        loginContinuation?.resume()
        loginContinuation = nil
    }

    func resumeRegister() {
        registerContinuation?.resume()
        registerContinuation = nil
    }

    func setShouldSuspendOnLogin(_ value: Bool) {
        shouldSuspendOnLogin = value
    }

    func setShouldSuspendOnRegister(_ value: Bool) {
        shouldSuspendOnRegister = value
    }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        registerCallCount += 1
        if shouldSuspendOnRegister {
            await withCheckedContinuation { continuation in
                registerContinuation = continuation
            }
        }
        if let registerError {
            throw registerError
        }
        let newSession = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        session = newSession
        return newSession
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        loginCallCount += 1
        if shouldSuspendOnLogin {
            await withCheckedContinuation { continuation in
                loginContinuation = continuation
            }
        }
        if let loginError {
            throw loginError
        }
        let newSession = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        session = newSession
        return newSession
    }

    func logout() async throws {
        session = nil
        user = nil
    }

    func refreshSession() async throws -> AuthSession {
        guard let session else {
            throw AuthRepositoryError.notAuthenticated
        }
        return session
    }
}

actor MockVaultRepository: VaultRepository {
    var readHeaderCallCount = 0
    var writeHeaderCallCount = 0
    var headerData = Data([0x01, 0x02, 0x03])
    var readHeaderError: VaultRepositoryError?
    var writeHeaderError: VaultRepositoryError?

    func readHeader() async throws -> Data {
        readHeaderCallCount += 1
        if let readHeaderError {
            throw readHeaderError
        }
        return headerData
    }

    func writeHeader(_ header: Data) async throws {
        writeHeaderCallCount += 1
        if let writeHeaderError {
            throw writeHeaderError
        }
    }

    func fetchPublicKey(userID: String) async throws -> Data {
        Data()
    }
}

final class MockVaultAuthenticator: VaultAuthenticator, @unchecked Sendable {
    var createVaultCallCount = 0
    var unlockVaultCallCount = 0
    var createVaultError: Error?
    var unlockVaultError: Error?
    var creationOutcome = VaultCreationOutcome(headerData: Data([0x0A]), mnemonic: ["abandon"])
    var unlockOutcome = VaultUnlockOutcome(
        sessionKeys: VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
    )

    func createVault(password: String) throws -> VaultCreationOutcome {
        createVaultCallCount += 1
        if let createVaultError {
            throw createVaultError
        }
        return creationOutcome
    }

    func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome {
        unlockVaultCallCount += 1
        if let unlockVaultError {
            throw unlockVaultError
        }
        return unlockOutcome
    }
}

actor MockVaultSession: VaultSessionProtocol {
    private(set) var establishedKeys: VaultSessionKeys?

    var isActive: Bool {
        establishedKeys != nil
    }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func establish(_ keys: VaultSessionKeys) {
        establishedKeys = keys
    }

    func clear() {
        establishedKeys = nil
    }

    func udk() throws -> SymmetricKey {
        guard let establishedKeys else {
            throw VaultSessionError.notActive
        }
        return establishedKeys.udk
    }

    func identityPrivateKey() throws -> Data {
        guard let establishedKeys else {
            throw VaultSessionError.notActive
        }
        return establishedKeys.identityPrivateKey
    }
}

@MainActor
final class MockLoginNavigator: LoginNavigating {
    private(set) var showRegisterCallCount = 0

    func showRegister() {
        showRegisterCallCount += 1
    }
}
