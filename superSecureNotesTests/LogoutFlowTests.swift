import AuthFlowRoutes
import CryptoKit
import NavigationProtocol
import NotesFlow
import NotesFlowRoutes
import VaultSession
import XCTest

@testable import superSecureNotes

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
final class LogoutFlowTests: XCTestCase {
    func testLogoutClearsVaultSessionAndNavigatesToLogin() async {
        let vaultSession = VaultSession()
        let viewModel = DefaultNoteListViewModel(
            authRepository: InMemoryAuthRepository(),
            vaultSession: vaultSession
        )
        let navigator = MockNavigating()
        await vaultSession.establish(
            VaultSessionKeys(
                udk: SymmetricKey(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )
        SessionRootNavigation.apply(isVaultActive: true, to: navigator)

        await viewModel.logout()

        let isActive = await vaultSession.isActive
        SessionRootNavigation.apply(isVaultActive: isActive, to: navigator)
        XCTAssertFalse(isActive)
        XCTAssertEqual(navigator.setRootRoutes.last?.base as? AuthRoute, .login)
    }
}
