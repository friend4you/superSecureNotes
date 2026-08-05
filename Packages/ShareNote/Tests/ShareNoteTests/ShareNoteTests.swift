import CryptoKit
import Foundation
import Navigation
import NavigationProtocol
import NoteRepositoryProtocol
import SecureCrypto
import ShareNote
import ShareNoteRoutes
import VaultRepositoryProtocol
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var popCallCount = 0
    private(set) var dismissPresentationCallCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() { popCallCount += 1 }
    func popToRoot() {}
    func dismissPresentation() { dismissPresentationCallCount += 1 }
}

@MainActor
private final class MockShareNoteDependencies: ShareNoteDependencyProviding {
    private let navigator: any Navigating
    private let noteRepository: any NoteRepository
    private let vaultRepository: any VaultRepository
    private let vaultSession: any VaultSessionProtocol

    init(
        navigator: any Navigating,
        noteRepository: any NoteRepository = ShareNoteTestMocks.NoteRepo(),
        vaultRepository: any VaultRepository = ShareNoteTestMocks.VaultRepo(),
        vaultSession: any VaultSessionProtocol = ShareNoteTestMocks.VaultSession()
    ) {
        self.navigator = navigator
        self.noteRepository = noteRepository
        self.vaultRepository = vaultRepository
        self.vaultSession = vaultSession
    }

    func makeShareNoteViewModel(noteID: UUID) -> DefaultShareNoteViewModel {
        DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultRepository: vaultRepository,
            vaultSession: vaultSession,
            navigator: navigator
        )
    }
}

private enum ShareNoteTestMocks {
    static func makeStoredNote(
        noteID: UUID,
        udk: SymmetricKey,
        syncState: NoteSyncState
    ) throws -> StoredNote {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data("body".utf8))
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        return StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Shared",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload,
            syncState: syncState
        )
    }

    actor NoteRepo: NoteRepository {
        private var note: StoredNote?
        private(set) var shareCalls: [(noteID: UUID, email: String, wrappedFEK: Data)] = []
        var shareError: Error?

        func setNote(_ note: StoredNote?) {
            self.note = note
        }

        func listNotes() async throws -> [NoteSummary] { [] }

        func readNote(noteID: UUID) async throws -> StoredNote {
            guard let note, note.metadata.noteID == noteID else {
                throw NoteRepositoryError.noteNotFound
            }
            return note
        }

        func writeNote(_ note: StoredNote) async throws {}
        func deleteNote(noteID: UUID) async throws {}

        func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
            if let shareError { throw shareError }
            shareCalls.append((noteID, recipientEmail, wrappedFEK))
        }

        func listSharedNotes() async throws -> [SharedNoteSummary] { [] }

        func readSharedNote(noteID: UUID) async throws -> SharedNote {
            throw NoteRepositoryError.notSupported
        }
    }

    actor VaultRepo: VaultRepository {
        private var publicKey = Data(repeating: 0x42, count: 32)
        private var fetchError: VaultRepositoryError?
        private(set) var fetchedEmails: [String] = []

        func setPublicKey(_ publicKey: Data) {
            self.publicKey = publicKey
        }

        func setFetchError(_ error: VaultRepositoryError?) {
            fetchError = error
        }

        func readHeader() async throws -> Data { Data() }
        func writeHeader(_ header: Data) async throws {}
        func fetchPublicKey(userID: String) async throws -> Data { publicKey }

        func fetchPublicKey(email: String) async throws -> Data {
            fetchedEmails.append(email)
            if let fetchError { throw fetchError }
            return publicKey
        }
    }

    actor VaultSession: VaultSessionProtocol {
        let udkKey: SymmetricKey
        let identityPrivate: Data

        init(
            udk: SymmetricKey = SymmetricKey(size: .bits256),
            identityPrivateKey: Data = Curve25519.KeyAgreement.PrivateKey().rawRepresentation
        ) {
            udkKey = udk
            identityPrivate = identityPrivateKey
        }

        var isActive: Bool { true }
        nonisolated var changes: AsyncStream<Bool> {
            AsyncStream { $0.finish() }
        }

        func establish(_ keys: VaultSessionKeys) {}
        func clear() {}
        func udk() throws -> SymmetricKey { udkKey }
        func identityPrivateKey() throws -> Data { identityPrivate }
    }
}

@MainActor
final class DefaultShareNoteViewModelTests: XCTestCase {
    func testViewModelExposesNoteID() {
        let noteID = UUID()
        let viewModel = DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: ShareNoteTestMocks.NoteRepo(),
            vaultRepository: ShareNoteTestMocks.VaultRepo(),
            vaultSession: ShareNoteTestMocks.VaultSession(),
            navigator: MockNavigating()
        )

        XCTAssertEqual(viewModel.noteID, noteID)
    }

    func testDismissCallsDismissPresentation() {
        let navigator = MockNavigating()
        let viewModel = DefaultShareNoteViewModel(
            noteID: UUID(),
            noteRepository: ShareNoteTestMocks.NoteRepo(),
            vaultRepository: ShareNoteTestMocks.VaultRepo(),
            vaultSession: ShareNoteTestMocks.VaultSession(),
            navigator: navigator
        )

        viewModel.dismiss()

        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
        XCTAssertEqual(navigator.popCallCount, 0)
    }

    func testShareSucceedsAndDismisses() async throws {
        let noteID = UUID()
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = ShareNoteTestMocks.NoteRepo()
        await noteRepository.setNote(
            try ShareNoteTestMocks.makeStoredNote(
                noteID: noteID,
                udk: udk,
                syncState: .synced
            )
        )
        let vaultRepository = ShareNoteTestMocks.VaultRepo()
        await vaultRepository.setPublicKey(recipient.publicKey.rawRepresentation)
        let navigator = MockNavigating()
        let viewModel = DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultRepository: vaultRepository,
            vaultSession: ShareNoteTestMocks.VaultSession(udk: udk),
            navigator: navigator
        )
        viewModel.recipientEmail = "friend@example.com"

        await viewModel.share()

        let shareCalls = await noteRepository.shareCalls
        XCTAssertEqual(shareCalls.count, 1)
        XCTAssertEqual(shareCalls.first?.noteID, noteID)
        XCTAssertEqual(shareCalls.first?.email, "friend@example.com")
        XCTAssertNotNil(shareCalls.first?.wrappedFEK)
        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSharing)
    }

    func testShareBlocksUnsyncedNote() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = ShareNoteTestMocks.NoteRepo()
        await noteRepository.setNote(
            try ShareNoteTestMocks.makeStoredNote(
                noteID: noteID,
                udk: udk,
                syncState: .pendingSync
            )
        )
        let vaultRepository = ShareNoteTestMocks.VaultRepo()
        let navigator = MockNavigating()
        let viewModel = DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultRepository: vaultRepository,
            vaultSession: ShareNoteTestMocks.VaultSession(udk: udk),
            navigator: navigator
        )
        viewModel.recipientEmail = "friend@example.com"

        await viewModel.share()

        let shareCalls = await noteRepository.shareCalls
        let fetchedEmails = await vaultRepository.fetchedEmails
        XCTAssertTrue(shareCalls.isEmpty)
        XCTAssertTrue(fetchedEmails.isEmpty)
        XCTAssertEqual(navigator.dismissPresentationCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "Sync this note before sharing.")
    }

    func testShareSurfacesPublicKeyNotFound() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = ShareNoteTestMocks.NoteRepo()
        await noteRepository.setNote(
            try ShareNoteTestMocks.makeStoredNote(
                noteID: noteID,
                udk: udk,
                syncState: .synced
            )
        )
        let vaultRepository = ShareNoteTestMocks.VaultRepo()
        await vaultRepository.setFetchError(.publicKeyNotFound)
        let navigator = MockNavigating()
        let viewModel = DefaultShareNoteViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultRepository: vaultRepository,
            vaultSession: ShareNoteTestMocks.VaultSession(udk: udk),
            navigator: navigator
        )
        viewModel.recipientEmail = "missing@example.com"

        await viewModel.share()

        let shareCalls = await noteRepository.shareCalls
        XCTAssertTrue(shareCalls.isEmpty)
        XCTAssertEqual(navigator.dismissPresentationCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "No account found for that email.")
    }
}

@MainActor
final class ShareNoteDependenciesTests: XCTestCase {
    func testShareNoteDependenciesConformsToShareNoteDependencyProviding() {
        let dependencies: any ShareNoteDependencyProviding = ShareNoteDependencies(
            navigator: MockNavigating(),
            noteRepository: ShareNoteTestMocks.NoteRepo(),
            vaultRepository: ShareNoteTestMocks.VaultRepo(),
            vaultSession: ShareNoteTestMocks.VaultSession()
        )

        XCTAssertTrue(dependencies is ShareNoteDependencies)
    }

    func testMakeShareNoteViewModelReturnsDefaultImplementationWithMatchingNoteID() {
        let noteID = UUID()
        let dependencies = ShareNoteDependencies(
            navigator: MockNavigating(),
            noteRepository: ShareNoteTestMocks.NoteRepo(),
            vaultRepository: ShareNoteTestMocks.VaultRepo(),
            vaultSession: ShareNoteTestMocks.VaultSession()
        )

        let viewModel = dependencies.makeShareNoteViewModel(noteID: noteID)

        XCTAssertTrue(viewModel is DefaultShareNoteViewModel)
        XCTAssertEqual(viewModel.noteID, noteID)
    }
}

@MainActor
final class ShareNoteViewTests: XCTestCase {
    func testShareNoteViewAcceptsViewModel() {
        let viewModel = DefaultShareNoteViewModel(
            noteID: UUID(),
            noteRepository: ShareNoteTestMocks.NoteRepo(),
            vaultRepository: ShareNoteTestMocks.VaultRepo(),
            vaultSession: ShareNoteTestMocks.VaultSession(),
            navigator: MockNavigating()
        )

        _ = ShareNoteView(viewModel: viewModel)
    }

    func testShareNoteViewSourceIncludesEmailFieldAndShareButton() throws {
        let source = try Self.shareNoteViewSource()
        XCTAssertTrue(source.contains("TextField("))
        XCTAssertTrue(source.contains("$viewModel.recipientEmail"))
        XCTAssertTrue(source.contains("share.emailField"))
        XCTAssertTrue(source.contains("share.button"))
    }

    func testShareNoteViewSourceDisablesShareWhileLoading() throws {
        let source = try Self.shareNoteViewSource()
        XCTAssertTrue(source.contains(".disabled(viewModel.isSharing)"))
        XCTAssertTrue(source.contains("viewModel.isSharing"))
    }

    private static func shareNoteViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/ShareNote/ShareNoteView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

@MainActor
final class ShareNoteNavigationTests: XCTestCase {
    func testViewForShareBuildsShareNoteView() {
        let noteID = UUID()
        let deps = MockShareNoteDependencies(navigator: MockNavigating())

        _ = ShareNoteNavigation.shareView(noteID: noteID, deps: deps)
    }

    func testViewForShareUsesDependencyProviding() {
        let noteID = UUID()
        let deps = MockShareNoteDependencies(navigator: MockNavigating())

        _ = ShareNoteNavigation.view(for: .share(noteID: noteID), deps: deps)
    }

    func testRegisterShareNoteRoutesResolvesRegisteredRoute() {
        let deps = MockShareNoteDependencies(navigator: MockNavigating())
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.registerShareNoteRoutes(deps: deps)

        let noteID = UUID()
        _ = registry.view(for: ShareNoteRoute.share(noteID: noteID))

        XCTAssertTrue(registry.isRegistered(ShareNoteRoute.self))
    }
}
