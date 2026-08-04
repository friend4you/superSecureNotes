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
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
        )
        await viewModel.load()

        XCTAssertFalse(viewModel.canSave)
    }

    func testSaveIsEnabledAfterChangesWithNonEmptyTitle() async throws {
        let noteID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let noteData = try NoteViewModelTestSupport.makeStoredNote(
            noteID: noteID,
            title: "Title",
            body: "Body",
            udk: udk
        )
        let viewModel = makeViewModel(
            noteID: noteID,
            noteRepository: StoredNoteMockRepository(notes: [noteID: noteData]),
            vaultSession: StoredNoteMockVaultSession(udk: udk)
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
        let noteRepository = StoredNoteMockRepository()
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
        XCTAssertTrue(source.contains("NoteAttachmentsSection("))
        XCTAssertTrue(source.contains("viewModel.attachmentItems"))
        XCTAssertTrue(source.contains("viewModel.removeAttachment(id:)"))
        XCTAssertTrue(source.contains("attachmentPreview($attachmentPreview)"))
    }

    func testNoteDetailViewSourceIncludesAttachmentPickers() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("PhotosPicker("))
        XCTAssertTrue(source.contains(".fileImporter("))
        XCTAssertTrue(source.contains("NoteAttachmentImportSupport"))
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

    func testNoteDetailViewSourceShowsSyncStatus() throws {
        let source = try Self.noteDetailViewSource()

        XCTAssertTrue(source.contains("viewModel.syncState"))
        XCTAssertTrue(source.contains("NoteSyncStatusLabel(syncState: viewModel.syncState)"))
    }

    func testNoteDetailViewSourceObservesSyncStateFromViewModel() throws {
        let detailSource = try Self.noteDetailViewSource()
        let statusLabelSource = try Self.noteSyncStatusLabelSource()

        XCTAssertTrue(detailSource.contains("viewModel.syncState"))
        XCTAssertTrue(statusLabelSource.contains("notes.sync.pending"))
        XCTAssertTrue(statusLabelSource.contains("notes.sync.synced"))
    }

    func testNoteSyncStatusLabelSourceUsesLocalizedStrings() throws {
        let source = try Self.noteSyncStatusLabelSource()

        XCTAssertTrue(source.contains("notes.sync.pending"))
        XCTAssertTrue(source.contains("notes.sync.synced"))
        XCTAssertTrue(source.contains("NotesFlowUILocalization.localized"))
    }

    @MainActor
    private func makeViewModel(
        noteID: UUID = UUID(),
        noteRepository: StoredNoteMockRepository = StoredNoteMockRepository(),
        vaultSession: StoredNoteMockVaultSession = StoredNoteMockVaultSession(),
        navigator: MockNavigating? = nil
    ) -> DefaultNoteDetailViewModel {
        DefaultNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating()
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

    private static func noteSyncStatusLabelSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/NoteSyncStatusLabel.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
