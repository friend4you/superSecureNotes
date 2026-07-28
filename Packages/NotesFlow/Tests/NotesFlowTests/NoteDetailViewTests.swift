import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import ShareNoteRoutes
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var presentedRoutes: [(route: AnyHashable, style: RoutePresentation)] = []
    private(set) var popCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {
        presentedRoutes.append((AnyHashable(route), style))
    }
    func pop() {
        popCount += 1
    }
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class NoteDetailViewTests: XCTestCase {
    func testNoteDetailViewAcceptsViewModel() {
        _ = NoteDetailView(viewModel: makeViewModel())
    }

    func testSaveIsDisabledWhenCannotSave() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
        )
        await viewModel.load()

        XCTAssertFalse(viewModel.canSave)
    }

    func testSaveIsEnabledAfterChangesWithNonEmptyTitle() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try makeEncryptedNoteFile(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: MockNoteRepository(notes: [noteID: noteData]),
            vaultSession: MockVaultSession(udk: udk)
        )
        await viewModel.load()
        viewModel.body = "Updated body"

        XCTAssertTrue(viewModel.canSave)
    }

    func testShareCallsViewModelShare() {
        let noteID = UUID()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(noteID: noteID, navigator: navigator)

        viewModel.share()

        XCTAssertEqual(navigator.presentedRoutes.count, 1)
        XCTAssertEqual(
            navigator.presentedRoutes.first?.route.base as? ShareNoteRoute,
            .share(noteID: noteID)
        )
    }

    func testDeleteConfirmationCallsViewModelDelete() async {
        let noteID = UUID()
        let noteRepository = MockNoteRepository()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            navigator: navigator
        )

        await viewModel.delete()

        let deletedNoteIDs = await noteRepository.deletedNoteIDs
        XCTAssertEqual(deletedNoteIDs, [noteID])
        XCTAssertEqual(navigator.popCount, 1)
    }

    func testNoteDetailViewSourceDisablesSaveWhenCannotSave() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains(".disabled(!viewModel.canSave)"))
    }

    func testNoteDetailViewSourceShareCallsViewModelShare() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("viewModel.share()"))
    }

    func testNoteDetailViewSourceShowsDeleteConfirmation() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("showsDeleteConfirmation"))
        XCTAssertTrue(source.contains("notes.delete.confirmation"))
        XCTAssertTrue(source.contains("await viewModel.delete()"))
    }

    func testNoteDetailViewSourceUsesTitleFieldBodyEditorAndAttachments() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("TextField("))
        XCTAssertTrue(source.contains("TextEditor(text: $viewModel.body)"))
        XCTAssertTrue(source.contains("viewModel.attachmentFilenames"))
    }

    func testNoteDetailViewSourceUsesLocalizedStrings() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("notes.detail.title"))
        XCTAssertTrue(source.contains("NotesFlowUILocalization.localized"))
    }

    func testNoteDetailViewSourceShowsInlineLoadingAndError() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("viewModel.isLoading"))
        XCTAssertTrue(source.contains("viewModel.errorMessage"))
    }

    @MainActor
    private func makeViewModel(
        noteID: UUID = UUID(),
        noteRepository: MockNoteRepository = MockNoteRepository(),
        vaultSession: MockVaultSession = MockVaultSession(),
        navigator: MockNavigating? = nil
    ) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating()
        )
    }

    private func makeEncryptedNoteFile(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey
    ) throws -> Data {
        let fek = generateSymmetricKey()
        let payload = NotePayload(body: Data(body.utf8))
        let encryptedPayload = try encryptPayload(payload, with: fek)
        let wrappedFEK = try wrapFEK(fek, with: udk)
        let metadata = NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: 1_700_000_000,
            updatedAt: 1_700_000_100,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
        return try assembleNoteFile(
            metadata: metadata,
            wrappedFEK: wrappedFEK,
            encryptedPayload: encryptedPayload
        )
    }

    private static func noteDetailViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/NoteDetailView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private actor MockNoteRepository: NoteRepository {
    private var notes: [UUID: Data]
    private(set) var deletedNoteIDs: [UUID] = []

    init(notes: [UUID: Data] = [:]) {
        self.notes = notes
    }

    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data {
        guard let data = notes[noteID] else {
            throw NoteRepositoryError.noteNotFound
        }
        return data
    }
    func writeNote(noteID: UUID, data: Data) async throws {
        notes[noteID] = data
    }
    func deleteNote(noteID: UUID) async throws {
        deletedNoteIDs.append(noteID)
        notes.removeValue(forKey: noteID)
    }
}

private actor MockVaultSession: VaultSessionProtocol {
    private let key: SymmetricKey

    init(udk: SymmetricKey = SymmetricKey(size: .bits256)) {
        key = udk
    }

    var isActive: Bool { true }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { key }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}
