import AuthFlowProtocol
import AuthFlowRoutes
import CryptoKit
import Navigation
import NavigationProtocol
import NotesFlowRoutes
import SecureCrypto
import VaultSession
import XCTest

@testable import Navigation
@testable import superSecureNotes

@MainActor
final class BiometricEnrollmentGatingTests: XCTestCase {
    func testSetRootDoesNotDismissEnrollmentSheetWhenPending() {
        let router = NavigationRouter()
        let navigator = RouterNavigating(router: router)

        navigator.present(AuthRoute.biometricEnrollment, style: .sheet)

        SessionRootNavigation.apply(
            hasLocalSetup: true,
            isVaultActive: true,
            pendingEnrollment: true,
            to: navigator
        )

        XCTAssertEqual(router.presentedRoute?.base as? AuthRoute, .biometricEnrollment)
        XCTAssertNil(router.rootRoute?.route.base as? NotesRoute)
    }

    func testSyncRootRouteSkipsNotesWhilePendingEnrollment() async {
        let composition = AppComposition()
        let router = composition.navigation.hostModel.router
        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )

        composition.pendingBiometricEnrollmentStore.setPending(true)
        await composition.appDependencies.vaultSession.establish(keys)

        composition.syncRootRoute(hasLocalSetup: true, isVaultActive: true)

        XCTAssertNil(router.rootRoute?.route.base as? NotesRoute)
    }

    func testEnrollmentCompletionNavigatesToNotesAfterSkip() async {
        let composition = AppComposition()
        let router = composition.navigation.hostModel.router
        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )

        composition.pendingBiometricEnrollmentStore.setPending(true)
        composition.sessionPasswordCache.store("secret")
        await composition.appDependencies.vaultSession.establish(keys)
        composition.navigation.navigator.present(AuthRoute.biometricEnrollment, style: .sheet)

        composition.syncRootRoute(hasLocalSetup: true, isVaultActive: true)
        XCTAssertEqual(router.presentedRoute?.base as? AuthRoute, .biometricEnrollment)

        let enrollmentViewModel = composition.authDependencies.makeBiometricEnrollmentViewModel()
        enrollmentViewModel.skip()

        XCTAssertFalse(composition.pendingBiometricEnrollmentStore.isPending)
        XCTAssertEqual(router.rootRoute?.route.base as? NotesRoute, .list)
    }

    func testLockPreservesPendingEnrollmentAndClearsSessionCache() async throws {
        let composition = AppComposition()
        composition.pendingBiometricEnrollmentStore.setPending(true)
        composition.sessionPasswordCache.store("secret")

        composition.lockCoordinator.lock()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(composition.pendingBiometricEnrollmentStore.isPending)
        XCTAssertNil(composition.sessionPasswordCache.password())
    }
}

@MainActor
private final class RouterNavigating: Navigating {
    let router: NavigationRouter

    init(router: NavigationRouter) {
        self.router = router
    }

    func setRoot<R: Route>(_ route: R) {
        router.setRoot(route)
    }

    func push<R: Route>(_ route: R) {
        router.push(route)
    }

    func present<R: Route>(_ route: R, style: RoutePresentation) {
        router.present(route, style: style)
    }

    func pop() {
        router.pop()
    }

    func popToRoot() {
        router.popToRoot()
    }

    func dismissPresentation() {
        router.dismissPresentation()
    }
}
