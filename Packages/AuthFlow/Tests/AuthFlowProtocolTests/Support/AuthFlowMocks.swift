import AuthFlowDomain
import AuthFlowProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import CryptoKit
import Foundation
import NetworkProtocol
import NavigationProtocol
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
enum AuthFlowTestSupport {
    static func makeEstablishVaultSessionUseCase(
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        noteSync: any NoteSyncing = MockNoteSyncService()
    ) -> DefaultEstablishVaultSessionUseCase {
        DefaultEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            noteSync: noteSync
        )
    }

    static func makeRestoreOnlineSessionUseCase(
        credentialStore: any CredentialStore = MockCredentialStore(),
        authRepository: any AuthRepository = MockAuthRepository()
    ) -> DefaultRestoreOnlineSessionUseCase {
        DefaultRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )
    }

    static func makeBiometricUnlockUseCase(
        credentialStore: any CredentialStore = MockCredentialStore(),
        biometricAuthenticator: any BiometricAuthenticator = MockBiometricAuthenticator()
    ) -> DefaultBiometricUnlockUseCase {
        DefaultBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )
    }

    static func makeLoginUseCase(
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true),
        noteSync: any NoteSyncing = MockNoteSyncService(),
        establishVaultSession: (any EstablishVaultSessionUseCase)? = nil,
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore()
    ) -> DefaultLoginUseCase {
        let establish = establishVaultSession ?? makeEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            noteSync: noteSync
        )
        return DefaultLoginUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establish
        )
    }

    static func makeRegisterUseCase(
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true),
        noteSync: any NoteSyncing = MockNoteSyncService(),
        establishVaultSession: (any EstablishVaultSessionUseCase)? = nil,
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore()
    ) -> DefaultRegisterUseCase {
        let establish = establishVaultSession ?? makeEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            noteSync: noteSync
        )
        return DefaultRegisterUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establish
        )
    }

    static func makeUnlockUseCase(
        credentialStore: any CredentialStore = MockCredentialStore(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: false),
        noteSync: any NoteSyncing = MockNoteSyncService(),
        establishVaultSession: (any EstablishVaultSessionUseCase)? = nil,
        restoreOnlineSession: (any RestoreOnlineSessionUseCase)? = nil,
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore()
    ) -> DefaultUnlockUseCase {
        let establish = establishVaultSession ?? makeEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore,
            noteSync: noteSync
        )
        let restore = restoreOnlineSession ?? makeRestoreOnlineSessionUseCase(
            credentialStore: credentialStore,
            authRepository: authRepository
        )
        return DefaultUnlockUseCase(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator,
            networkReachability: networkReachability,
            noteSync: noteSync,
            establishVaultSession: establish,
            restoreOnlineSession: restore
        )
    }

    static func makeLoginViewModel(
        loginUseCase: (any LoginUseCase)? = nil,
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        navigator: (any Navigating)? = nil,
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true),
        noteSync: any NoteSyncing = MockNoteSyncService()
    ) -> DefaultLoginViewModel {
        let useCase = loginUseCase ?? makeLoginUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )
        return DefaultLoginViewModel(
            loginUseCase: useCase,
            navigator: navigator ?? MockNavigating()
        )
    }

    static func makeRegisterViewModel(
        registerUseCase: (any RegisterUseCase)? = nil,
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultRepository: any VaultRepository = MockVaultRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        navigator: (any Navigating)? = nil,
        credentialStore: any CredentialStore = MockCredentialStore(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: true),
        noteSync: any NoteSyncing = MockNoteSyncService()
    ) -> DefaultRegisterViewModel {
        let useCase = registerUseCase ?? makeRegisterUseCase(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: vaultAuthenticator,
            credentialStore: credentialStore,
            networkReachability: networkReachability,
            noteSync: noteSync,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )
        return DefaultRegisterViewModel(
            registerUseCase: useCase,
            navigator: navigator ?? MockNavigating()
        )
    }

    static func makeUnlockViewModel(
        email: String = "user@example.com",
        unlockUseCase: (any UnlockUseCase)? = nil,
        biometricUnlockUseCase: (any BiometricUnlockUseCase)? = nil,
        credentialStore: any CredentialStore = MockCredentialStore(),
        authRepository: any AuthRepository = MockAuthRepository(),
        vaultAuthenticator: any VaultAuthenticator = MockVaultAuthenticator(),
        vaultSession: any VaultSessionProtocol = MockVaultSession(),
        notesIndexStore: any NotesIndexStoreProtocol = MockNotesIndexStore(),
        biometricAuthenticator: any BiometricAuthenticator = MockBiometricAuthenticator(),
        networkReachability: any NetworkReachability = MockNetworkReachability(isOnline: false),
        noteSync: any NoteSyncing = MockNoteSyncService(),
        performLogout: @escaping () async -> Void = {}
    ) -> DefaultUnlockViewModel {
        let unlock = unlockUseCase ?? makeUnlockUseCase(
            credentialStore: credentialStore,
            vaultAuthenticator: vaultAuthenticator,
            networkReachability: networkReachability,
            noteSync: noteSync,
            authRepository: authRepository,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )
        let biometric = biometricUnlockUseCase ?? makeBiometricUnlockUseCase(
            credentialStore: credentialStore,
            biometricAuthenticator: biometricAuthenticator
        )
        return DefaultUnlockViewModel(
            email: email,
            unlockUseCase: unlock,
            biometricUnlockUseCase: biometric,
            performLogout: performLogout
        )
    }
}

actor MockAuthRepository: AuthRepository {
    var loginCallCount = 0
    var registerCallCount = 0
    var logoutCallCount = 0
    var clearSessionCallCount = 0
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
        logoutCallCount += 1
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
        clearSessionCallCount += 1
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

    func fetchPublicKey(email: String) async throws -> Data {
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
    private(set) var clearCallCount = 0
    var onEstablish: (@Sendable () -> Void)?

    var isActive: Bool {
        establishedKeys != nil
    }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func establish(_ keys: VaultSessionKeys) {
        onEstablish?()
        establishedKeys = keys
    }

    func clear() {
        clearCallCount += 1
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
    private(set) var presentedRoutes: [(route: AnyHashable, style: RoutePresentation)] = []
    private(set) var dismissPresentationCallCount = 0

    func setRoot<R: Route>(_ route: R) {
        pushedRoutes = [AnyHashable(route)]
    }

    func push<R: Route>(_ route: R) {
        pushedRoutes.append(AnyHashable(route))
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoutes.append((AnyHashable(route), style))
    }

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

actor MockNoteSyncService: NoteSyncing {
    private(set) var flushCallCount = 0
    private(set) var uploadVaultHeaderCallCount = 0
    private(set) var pullVaultHeaderCallCount = 0
    private(set) var pullRemoteNotesCatalogCallCount = 0
    private(set) var pullRemoteSharedCatalogCallCount = 0
    var uploadVaultHeaderError: Error?
    var pullVaultHeaderError: Error?
    var pullVaultHeaderResult: Data?
    var localVaultHeaderExists = true
    var onPullRemoteNotesCatalog: (@Sendable () -> Void)?

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    func flushPending() async {
        flushCallCount += 1
    }

    func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        pullVaultHeaderCallCount += 1
        if let pullVaultHeaderError {
            throw pullVaultHeaderError
        }
        if localVaultHeaderExists {
            return nil
        }
        return pullVaultHeaderResult ?? Data([0x0B])
    }

    func pullRemoteNotesCatalog() async throws {
        pullRemoteNotesCatalogCallCount += 1
        onPullRemoteNotesCatalog?()
    }

    func pullRemoteSharedCatalog() async throws {
        pullRemoteSharedCatalogCallCount += 1
    }

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    func uploadVaultHeaderOrThrow(_ header: Data) async throws {
        uploadVaultHeaderCallCount += 1
        if let uploadVaultHeaderError {
            throw uploadVaultHeaderError
        }
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
