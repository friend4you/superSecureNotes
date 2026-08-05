import AuthRepositoryProtocol
import CredentialStoreProtocol
import CryptoKit
import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlowRoutes
import SecureCrypto
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
final class DefaultNoteListViewModelSharedTests: XCTestCase {
    func testDefaultSegmentIsMyNotes() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.selectedSegment, .myNotes)
    }

    func testRefreshLoadsSharedNotesWhenSharedSegmentSelected() async {
        let noteID = UUID()
        let summary = SharedNoteSummary(
            noteID: noteID,
            title: "Shared title",
            updatedAt: 1_700_000_200,
            etag: "etag",
            ownerEmail: "owner@example.com",
            ownerID: UUID(),
            sharedAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let noteRepository = SharedListMockNoteRepository(sharedNotes: [summary])
        let viewModel = makeViewModel(noteRepository: noteRepository)
        viewModel.selectedSegment = .shared

        await viewModel.refresh()

        let listCallCount = await noteRepository.listSharedNotesCallCount
        XCTAssertEqual(listCallCount, 1)
        XCTAssertEqual(viewModel.sharedNotes, [summary])
    }

    func testOpenSharedDetailPushesSharedDetailRoute() {
        let noteID = UUID()
        let navigator = RecordingNavigator()
        let viewModel = makeViewModel(navigator: navigator)

        viewModel.openSharedDetail(noteID: noteID)

        XCTAssertEqual(navigator.pushedRoutes.count, 1)
        XCTAssertEqual(
            navigator.pushedRoutes.first as? NotesRoute,
            .sharedDetail(noteID: noteID)
        )
    }

    private func makeViewModel(
        noteRepository: SharedListMockNoteRepository = SharedListMockNoteRepository(),
        navigator: RecordingNavigator? = nil
    ) -> DefaultNoteListViewModel {
        DefaultNoteListViewModel(
            authRepository: SharedListMockAuthRepository(),
            vaultSession: SharedListMockVaultSession(),
            noteRepository: noteRepository,
            navigator: navigator ?? RecordingNavigator(),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            performLogout: NotesFlowTestMocks.noopLogout
        )
    }
}

@MainActor
private final class RecordingNavigator: Navigating {
    private(set) var pushedRoutes: [any Route] = []

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) { pushedRoutes.append(route) }
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

private actor SharedListMockAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }
    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func logout() async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }
    func restoreSession(refreshToken: String) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }
    func clearSession() async {}
}

private actor SharedListMockVaultSession: VaultSessionProtocol {
    var isActive: Bool { true }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}

private actor SharedListMockNoteRepository: NoteRepository {
    private let sharedNotes: [SharedNoteSummary]
    private(set) var listSharedNotesCallCount = 0

    init(sharedNotes: [SharedNoteSummary] = []) {
        self.sharedNotes = sharedNotes
    }

    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> StoredNote {
        throw NoteRepositoryError.noteNotFound
    }
    func writeNote(_ note: StoredNote) async throws {}
    func deleteNote(noteID: UUID) async throws {}
    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        throw NoteRepositoryError.notSupported
    }
    func listSharedNotes() async throws -> [SharedNoteSummary] {
        listSharedNotesCallCount += 1
        return sharedNotes
    }
    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        throw NoteRepositoryError.notSupported
    }
}
