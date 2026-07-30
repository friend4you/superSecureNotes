import AuthFlowRoutes
import CredentialStore
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
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
        let navigator = MockNavigating()
        let credentialStore = KeychainCredentialStore(
            service: "com.superSecureNotes.tests.\(UUID().uuidString)",
            passwordAccessMode: .standard
        )
        let viewModel = DefaultNoteListViewModel(
            authRepository: InMemoryAuthRepository(),
            vaultSession: vaultSession,
            noteRepository: MockNoteRepository(),
            navigator: navigator,
            credentialStore: credentialStore
        )
        await vaultSession.establish(
            VaultSessionKeys(
                udk: SymmetricKey(size: .bits256),
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )
        SessionRootNavigation.apply(
            hasLocalSetup: false,
            isVaultActive: true,
            to: navigator
        )

        await viewModel.logout()

        let isActive = await vaultSession.isActive
        SessionRootNavigation.apply(
            hasLocalSetup: credentialStore.hasLocalSetup,
            isVaultActive: isActive,
            to: navigator
        )
        XCTAssertFalse(isActive)
        XCTAssertFalse(credentialStore.hasLocalSetup)
        XCTAssertEqual(navigator.setRootRoutes.last?.base as? AuthRoute, .login)
    }
}

private actor MockNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}
