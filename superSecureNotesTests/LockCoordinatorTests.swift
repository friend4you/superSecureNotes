import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStore
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepository
import NoteRepositoryProtocol
import SwiftUI
import VaultSession
import VaultSessionProtocol
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import superSecureNotes

@MainActor
private final class LockWaiter {
    private var continuation: CheckedContinuation<Void, Never>?

    func waitForLock() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func fulfill() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class MockNavigating: Navigating {
    private(set) var setRootRoutes: [AnyHashable] = []

    func setRoot<R: Route>(_ route: R) {
        setRootRoutes.append(AnyHashable(route))
    }

    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class LockCoordinatorTests: XCTestCase {
    private var credentialStore: KeychainCredentialStore!

    override func setUp() {
        super.setUp()
        credentialStore = KeychainCredentialStore(
            service: "com.superSecureNotes.lockCoordinator.\(UUID().uuidString)",
            passwordAccessMode: .standard
        )
    }

    override func tearDown() {
        try? credentialStore.clearAll()
        credentialStore = nil
        super.tearDown()
    }

    func testLockOnBackground() async throws {
        let (coordinator, waiter, vaultSession, authRepository) = makeLockCoordinator()
        try await establishActiveSession(vaultSession: vaultSession, authRepository: authRepository)

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.handleScenePhase(.background)
        }

        let isActive = await vaultSession.isActive
        let currentSession = await authRepository.currentSession
        XCTAssertFalse(isActive)
        XCTAssertNil(currentSession)
    }

    #if canImport(UIKit)
    func testLockOnDeviceLockScreen() async throws {
        let (coordinator, waiter, vaultSession, authRepository) = makeLockCoordinator()
        try await establishActiveSession(vaultSession: vaultSession, authRepository: authRepository)

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            NotificationCenter.default.post(
                name: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil
            )
        }

        let isActive = await vaultSession.isActive
        let currentSession = await authRepository.currentSession
        XCTAssertFalse(isActive)
        XCTAssertNil(currentSession)
    }
    #endif

    func testLockedOnForegroundReturn() async throws {
        let navigator = MockNavigating()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01])
        )

        let (coordinator, waiter, vaultSession, _) = makeLockCoordinator {
            SessionRootNavigation.apply(
                hasLocalSetup: self.credentialStore.hasLocalSetup,
                isVaultActive: false,
                to: navigator
            )
        }
        await vaultSession.establish(sampleVaultKeys())

        SessionRootNavigation.apply(
            hasLocalSetup: credentialStore.hasLocalSetup,
            isVaultActive: true,
            to: navigator
        )

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.handleScenePhase(.background)
        }

        coordinator.handleScenePhase(.active)

        XCTAssertEqual(navigator.setRootRoutes.last?.base as? AuthRoute, .unlock)
    }

    func testNoGracePeriod() async throws {
        let (coordinator, waiter, vaultSession, authRepository) = makeLockCoordinator()
        try await establishActiveSession(vaultSession: vaultSession, authRepository: authRepository)

        coordinator.handleScenePhase(.inactive)
        try await Task.sleep(nanoseconds: 10_000_000)

        let isActiveAfterInactive = await vaultSession.isActive
        XCTAssertTrue(isActiveAfterInactive)

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.handleScenePhase(.background)
        }

        let isActiveAfterBackground = await vaultSession.isActive
        XCTAssertFalse(isActiveAfterBackground)
    }

    func testLockClosesNotesIndexStoreBeforeClearingVaultSession() async throws {
        let notesIndexStore = NotesIndexStore()
        try await notesIndexStore.open(passphrase: Data([0x01]))
        let (coordinator, waiter, vaultSession, _) = makeLockCoordinator(
            notesIndexStore: notesIndexStore
        )
        await vaultSession.establish(sampleVaultKeys())

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.lock()
        }

        let isOpen = await notesIndexStore.isOpen
        let isActive = await vaultSession.isActive
        XCTAssertFalse(isOpen)
        XCTAssertFalse(isActive)
    }

    func testLockClearsVaultSession() async throws {
        let (coordinator, waiter, vaultSession, _) = makeLockCoordinator()
        await vaultSession.establish(sampleVaultKeys())
        let isActiveBeforeLock = await vaultSession.isActive
        XCTAssertTrue(isActiveBeforeLock)

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.lock()
        }

        let isActiveAfterLock = await vaultSession.isActive
        XCTAssertFalse(isActiveAfterLock)
        do {
            _ = try await vaultSession.udk()
            XCTFail("Expected vault session to be inactive")
        } catch {
            XCTAssertEqual(error as? VaultSessionError, .notActive)
        }
    }

    func testLockPreservesKeychainCredentials() async throws {
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01, 0x02])
        )
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword("secret")

        let (coordinator, waiter, _, authRepository) = makeLockCoordinator()
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )

        await triggerLockAndWait(coordinator: coordinator, waiter: waiter) {
            coordinator.lock()
        }

        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), "user@example.com")
        XCTAssertEqual(credentialStore.refreshToken(), "refresh-token")
        XCTAssertEqual(credentialStore.vaultHeader(), Data([0x01, 0x02]))
        XCTAssertTrue(credentialStore.bioEnabled())
        XCTAssertEqual(try credentialStore.loadPasswordWithBiometrics(), "secret")
    }

    @MainActor
    private func makeLockCoordinator(
        vaultSession: VaultSession = VaultSession(),
        authRepository: MockAuthRepository = MockAuthRepository(),
        notesIndexStore: NotesIndexStore = NotesIndexStore(),
        onLock: @escaping () -> Void = {}
    ) -> (LockCoordinator, LockWaiter, VaultSession, MockAuthRepository) {
        let waiter = LockWaiter()
        let coordinator = LockCoordinator(
            vaultSession: vaultSession,
            authRepository: authRepository,
            notesIndexStore: notesIndexStore
        ) {
            waiter.fulfill()
            onLock()
        }
        return (coordinator, waiter, vaultSession, authRepository)
    }

    private func triggerLockAndWait(
        coordinator: LockCoordinator,
        waiter: LockWaiter,
        trigger: () -> Void
    ) async {
        async let waiting: Void = waiter.waitForLock()
        trigger()
        await waiting
    }

    private func establishActiveSession(
        vaultSession: VaultSession,
        authRepository: MockAuthRepository
    ) async throws {
        await vaultSession.establish(sampleVaultKeys())
        _ = try await authRepository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )
    }

    private func sampleVaultKeys() -> VaultSessionKeys {
        VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
    }
}

private actor MockAuthRepository: AuthRepository {
    private var session: AuthSession?

    var currentSession: AuthSession? { session }
    var currentUser: User? { nil }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: .distantFuture
        )
        return session!
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: .distantFuture
        )
        return session!
    }

    func logout() async throws {
        session = nil
    }

    func refreshSession() async throws -> AuthSession {
        guard let session else {
            throw AuthRepositoryError.notAuthenticated
        }
        return session
    }

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        session = AuthSession(
            accessToken: "access",
            refreshToken: refreshToken,
            expiresAt: .distantFuture
        )
        return session!
    }

    func clearSession() async {
        session = nil
    }
}
