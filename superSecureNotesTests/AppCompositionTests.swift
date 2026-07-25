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
final class AppCompositionTests: XCTestCase {
    func testAppUsesNotesFlowDependencies() {
        let notesDependencies = NotesFlowDependencies(
            authRepository: InMemoryAuthRepository(),
            vaultSession: VaultSession(),
            navigator: MockNavigating()
        )

        XCTAssertTrue(notesDependencies is NotesDependencyProviding)
    }

    func testAppCompositionPassesAuthAndVaultSessionToNotesDependencies() {
        let composition = AppComposition()

        let viewModel = composition.notesDependencies.makeNoteListViewModel()

        XCTAssertTrue(viewModel is DefaultNoteListViewModel)
    }
}
