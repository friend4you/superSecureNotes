import AuthRepositoryProtocol
import AuthFlowProtocol
import CredentialStoreProtocol
import CryptoKit
import Foundation
import NetworkProtocol
import NavigationProtocol
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepositoryProtocol
import VaultSessionProtocol
import XCTest

@testable import AuthFlowProtocol

@MainActor
enum AuthFlowTestSupport {
    static func makeLoginViewModel(
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        navigator: (any Navigating)? = nil,
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true)
    ) -> DefaultLoginViewModel {
        DefaultLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            navigator: navigator ?? MockNavigating(),
            credentialStore: credentialStore,
            networkReachability: networkReachability
        )
    }

    static func makeRegisterViewModel(
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true),
        vaultHeaderUploader: any VaultHeaderUploadScheduling = MockVaultHeaderUploadScheduler()
    ) -> DefaultRegisterViewModel {
        DefaultRegisterViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            vaultHeaderUploader: vaultHeaderUploader
        )
    }

    static func makeUnlockViewModel(
        credentialStore: any CredentialStore = MockCredentialStore(),
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        biometricAuthenticator: any BiometricAuthenticator = MockBiometricAuthenticator(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: false),
        noteSync: any NoteSyncing = MockNoteSyncService()
    ) -> DefaultUnlockViewModel {
        DefaultUnlockViewModel(
            credentialStore: credentialStore,
            authRepository: authRepository,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            biometricAuthenticator: biometricAuthenticator,
            networkReachability: networkReachability,
            noteSync: noteSync
        )
    }
}

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
            notesIndexStore: MockNotesIndexStore(),
            navigator: MockNavigating(),
            credentialStore: MockCredentialStore(),
            networkReachability: MockNetworkReachability(isOnline: true)
        )

        XCTAssertEqual(viewModel.state, .idle)
    }
}

actor MockAuthRepository: AuthRepository {
    var loginCallCount = 0
    var registerCallCount = 0
    var loginError: AuthRepositoryError?
    var registerError: AuthRepositoryError?
    var restoreError: AuthRepositoryError?
    private(set) var restoreSessionCallCount = 0
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

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        restoreSessionCallCount += 1
        if let restoreError {
            throw restoreError
        }
        let newSession = AuthSession(
            accessToken: "access",
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        session = newSession
        return newSession
    }

    func clearSession() async {
        session = nil
        user = nil
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
    private(set) var lastUnlockHeaderData: Data?
    private(set) var lastUnlockPassword: String?

    func createVault(password: String) throws -> VaultCreationOutcome {
        createVaultCallCount += 1
        if let createVaultError {
            throw createVaultError
        }
        return creationOutcome
    }

    func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome {
        unlockVaultCallCount += 1
        lastUnlockHeaderData = headerData
        lastUnlockPassword = password
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
final class MockNavigating: Navigating {
    private(set) var pushedRoutes: [AnyHashable] = []
    private(set) var dismissPresentationCallCount = 0

    func setRoot<R: Route>(_ route: R) {
        pushedRoutes = [AnyHashable(route)]
    }

    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {}

    func pop() {}

    func popToRoot() {}

    func dismissPresentation() {
        dismissPresentationCallCount += 1
    }
}

final class MockCredentialStore: CredentialStore, @unchecked Sendable {
    private var setup = false
    private var storedEmail: String?
    private var storedRefreshToken: String?
    private var storedVaultHeader: Data?
    private var storedBioEnabled = false
    private var storedPassword: String?

    var hasLocalSetup: Bool { setup }

    func markSetupComplete() throws { setup = true }

    func saveEmail(_ email: String) throws { storedEmail = email }
    func email() -> String? { storedEmail }

    func saveRefreshToken(_ token: String) throws { storedRefreshToken = token }
    func refreshToken() -> String? { storedRefreshToken }

    func saveVaultHeader(_ header: Data) throws { storedVaultHeader = header }
    func vaultHeader() -> Data? { storedVaultHeader }

    func bioEnabled() -> Bool { storedBioEnabled }

    func setBioEnabled(_ enabled: Bool) throws {
        storedBioEnabled = enabled
        if !enabled { storedPassword = nil }
    }

    func savePassword(_ password: String) throws {
        guard storedBioEnabled else { throw CredentialStoreError.storageFailed }
        storedPassword = password
    }

    func loadPasswordWithBiometrics() throws -> String {
        guard storedBioEnabled, let storedPassword else {
            throw CredentialStoreError.itemNotFound
        }
        return storedPassword
    }

    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {
        try saveEmail(email)
        try saveRefreshToken(refreshToken)
        try saveVaultHeader(vaultHeader)
        try markSetupComplete()
    }

    func clearAll() throws {
        setup = false
        storedEmail = nil
        storedRefreshToken = nil
        storedVaultHeader = nil
        storedBioEnabled = false
        storedPassword = nil
    }
}

struct MockNetworkReachability: NetworkReachability {
    let isOnline: Bool
    var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(isOnline)
            continuation.finish()
        }
    }
}

final class MockVaultHeaderUploadScheduler: VaultHeaderUploadScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var headers: [Data] = []

    var scheduledHeaders: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return headers
    }

    func scheduleVaultHeaderUpload(_ header: Data) {
        lock.lock()
        headers.append(header)
        lock.unlock()
    }
}

actor MockNoteSyncService: NoteSyncing {
    private(set) var flushCallCount = 0

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    func flushPending() async {
        flushCallCount += 1
    }

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    nonisolated func scheduleFlush() {
        Task { await flushPending() }
    }

    nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}

actor MockNotesIndexStore: NotesIndexStoreProtocol {
    private(set) var isOpen = false
    private(set) var openCallCount = 0
    private(set) var closeCallCount = 0
    private(set) var lastPassphrase: Data?
    var openError: Error?

    func open(passphrase: Data) async throws {
        openCallCount += 1
        lastPassphrase = passphrase
        if let openError {
            throw openError
        }
        isOpen = true
    }

    func close() async {
        closeCallCount += 1
        isOpen = false
    }
}

final class MockBiometricAuthenticator: BiometricAuthenticator, @unchecked Sendable {
    var canEvaluate = true
    var result: BiometricAuthResult = .success
    private(set) var authenticateCallCount = 0

    func canEvaluateBiometrics() -> Bool { canEvaluate }

    func authenticate(reason: String) async -> BiometricAuthResult {
        authenticateCallCount += 1
        return result
    }
}
