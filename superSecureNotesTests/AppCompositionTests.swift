import AuthFlowProtocol
import AuthFlowRoutes
import CryptoKit
import CredentialStoreProtocol
import Navigation
import NavigationProtocol
import NoteRepository
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
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
            noteRepository: MockNoteRepository(),
            credentialStore: TestCredentialStore(),
            performLogout: {}
        )

        XCTAssertTrue(notesDependencies is NotesDependencyProviding)
    }

    func testAppCompositionPassesNoteRepositoryToNotesDependencies() async {
        let composition = AppComposition()

        guard let infrastructureRepository = composition.appDependencies.noteRepository as? LocalNoteRepository,
              let notesRepository = composition.notesDependencies.noteRepository as? LocalNoteRepository
        else {
            XCTFail("Expected LocalNoteRepository instances")
            return
        }

        XCTAssertTrue(infrastructureRepository === notesRepository)
        await Task.yield()
    }

    func testAppCompositionPassesAuthAndVaultSessionToNotesDependencies() async {
        let composition = AppComposition()

        let viewModel = composition.notesDependencies.makeNoteListViewModel()

        XCTAssertTrue(viewModel is DefaultNoteListViewModel)
        await Task.yield()
    }

    func testAppUsesShareNoteDependencies() {
        let shareNoteDependencies = ShareNoteDependencies(navigator: MockNavigating())

        XCTAssertTrue(shareNoteDependencies is ShareNoteDependencyProviding)
    }

    func testAppCompositionRegistersShareNoteRoute() async {
        let composition = AppComposition()

        XCTAssertTrue(composition.navigation.registry.isRegistered(ShareNoteRoute.self))
        await Task.yield()
    }

    func testAppCompositionRegistersNotesRoute() async {
        let composition = AppComposition()

        XCTAssertTrue(composition.navigation.registry.isRegistered(NotesRoute.self))
        await Task.yield()
    }

    func testNotesListToDetailNavigationViaRegistry() async {
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
        await Task.yield()
    }

    func testAppCompositionNotesRouteRegistryResolvesCreateRoute() async {
        let composition = AppComposition()

        _ = composition.navigation.registry.view(for: NotesRoute.create)
        await Task.yield()
    }

    func testAppCompositionExposesShareNoteDependencies() async {
        let composition = AppComposition()

        let noteID = UUID()
        let viewModel = composition.shareNoteDependencies.makeShareNoteViewModel(noteID: noteID)

        XCTAssertTrue(viewModel is DefaultShareNoteViewModel)
        XCTAssertEqual(viewModel.noteID, noteID)
        await Task.yield()
    }

    func testSyncRootRouteRoutesToUnlockWhenSetupWithoutActiveVault() async {
        let composition = AppComposition()

        XCTAssertTrue(composition.navigation.registry.isRegistered(AuthRoute.self))
        XCTAssertTrue(composition.authDependencies.makeUnlockViewModel() is DefaultUnlockViewModel)
        XCTAssertTrue(composition.lockCoordinator is LockCoordinator)

        let router = composition.navigation.hostModel.router
        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )

        composition.syncRootRoute(hasLocalSetup: false, isVaultActive: false)
        XCTAssertEqual(router.rootRoute?.route.base as? AuthRoute, .login)

        composition.syncRootRoute(hasLocalSetup: true, isVaultActive: false)
        XCTAssertEqual(router.rootRoute?.route.base as? AuthRoute, .unlock)

        await composition.appDependencies.vaultSession.establish(keys)
        composition.syncRootRoute(hasLocalSetup: true, isVaultActive: true)
        XCTAssertEqual(router.rootRoute?.route.base as? NotesRoute, .list)
    }
}

private actor MockNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "",
                createdAt: 0,
                updatedAt: 0,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data(),
            encryptedPayload: Data([0x01]),
            syncState: .pendingSync
        )
    }
    func writeNote(_ note: StoredNote) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}

private final class TestCredentialStore: CredentialStore, @unchecked Sendable {
    var hasLocalSetup: Bool { false }
    func markSetupComplete() throws {}
    func saveEmail(_ email: String) throws {}
    func email() -> String? { nil }
    func saveRefreshToken(_ token: String) throws {}
    func refreshToken() -> String? { nil }
    func saveVaultHeader(_ header: Data) throws {}
    func vaultHeader() -> Data? { nil }
    func bioEnabled() -> Bool { false }
    func setBioEnabled(_ enabled: Bool) throws {}
    func savePassword(_ password: String) throws {}
    func loadPasswordWithBiometrics() throws -> String { throw CredentialStoreError.itemNotFound }
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}
    func clearAll() throws {}
}
