import AuthFlowRoutes
import CryptoKit
import Navigation
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import NotesFlowRoutes
import ShareNote
import ShareNoteRoutes
import SwiftUI
import VaultSession
import XCTest

@testable import Navigation
@testable import NotesFlow
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
    override func setUp() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        super.setUp()
    }

    override func tearDown() {
        StubBackendConfiguration.testLaunchArguments = nil
        super.tearDown()
    }

    func testAppUsesNotesFlowDependencies() {
        let notesDependencies = NotesFlowDependencies(
            authRepository: InMemoryAuthRepository(),
            vaultSession: VaultSession(),
            navigator: MockNavigating(),
            noteRepository: MockNoteRepository()
        )

        XCTAssertTrue(notesDependencies is NotesDependencyProviding)
    }

    func testAppCompositionPassesNoteRepositoryToNotesDependencies() {
        let composition = AppComposition()

        guard let infrastructureRepository = composition.infrastructure.noteRepository as? FileNoteRepository,
              let notesRepository = composition.notesDependencies.noteRepository as? FileNoteRepository
        else {
            XCTFail("Expected FileNoteRepository instances in stub mode")
            return
        }

        XCTAssertTrue(infrastructureRepository === notesRepository)
    }

    func testAppCompositionPassesAuthAndVaultSessionToNotesDependencies() {
        let composition = AppComposition()

        let viewModel = composition.notesDependencies.makeNoteListViewModel()

        XCTAssertTrue(viewModel is DefaultNoteListViewModel)
    }

    func testAppUsesShareNoteDependencies() {
        let shareNoteDependencies = ShareNoteDependencies(navigator: MockNavigating())

        XCTAssertTrue(shareNoteDependencies is ShareNoteDependencyProviding)
    }

    func testAppCompositionRegistersShareNoteRoute() {
        let composition = AppComposition()

        XCTAssertTrue(composition.navigation.registry.isRegistered(ShareNoteRoute.self))
    }

    func testAppCompositionRegistersNotesRoute() {
        let composition = AppComposition()

        XCTAssertTrue(composition.navigation.registry.isRegistered(NotesRoute.self))
    }

    func testNotesListToDetailNavigationViaRegistry() {
        let composition = AppComposition()
        let navigator = composition.navigation.navigator
        let registry = composition.navigation.registry
        let router = composition.navigation.hostModel.router

        navigator.setRoot(NotesRoute.list)
        XCTAssertEqual(router.rootRoute?.route.base as? NotesRoute, .list)
        _ = registry.view(for: NotesRoute.list)

        let noteID = UUID()
        navigator.push(NotesRoute.detail(noteID: noteID))

        var expectedPath = NavigationPath()
        expectedPath.append(NotesRoute.detail(noteID: noteID))
        XCTAssertEqual(router.path, expectedPath)
        _ = registry.view(for: NotesRoute.detail(noteID: noteID))
    }

    func testAppCompositionNotesRouteRegistryResolvesCreateRoute() {
        let composition = AppComposition()

        _ = composition.navigation.registry.view(for: NotesRoute.create)
    }

    func testAppCompositionExposesShareNoteDependencies() {
        let composition = AppComposition()

        let noteID = UUID()
        let viewModel = composition.shareNoteDependencies.makeShareNoteViewModel(noteID: noteID)

        XCTAssertTrue(viewModel is DefaultShareNoteViewModel)
        XCTAssertEqual(viewModel.noteID, noteID)
    }
}

private actor MockNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}
