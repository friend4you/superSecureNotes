import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import VaultSessionProtocol
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var popCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {
        popCount += 1
    }
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class CreateNoteViewTests: XCTestCase {
    func testCreateNoteViewAcceptsViewModel() {
        _ = CreateNoteView(viewModel: makeViewModel())
    }

    func testSaveIsDisabledWhenCannotSave() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.canSave)
    }

    func testSaveIsEnabledWithNonEmptyTitle() {
        let viewModel = makeViewModel()
        viewModel.title = "New note"

        XCTAssertTrue(viewModel.canSave)
    }

    func testPhotoSelectionAddsAttachmentViaViewModel() {
        let viewModel = makeViewModel()
        viewModel.title = "Photo note"
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: UUID().uuidString,
                filename: "photo.jpg",
                mime: "image/jpeg",
                data: Data([0xFF, 0xD8, 0xFF])
            )
        )

        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["photo.jpg"])
        XCTAssertTrue(viewModel.canSave)
    }

    func testFileSelectionAddsAttachmentViaViewModel() {
        let viewModel = makeViewModel()
        viewModel.title = "File note"
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: UUID().uuidString,
                filename: "document.pdf",
                mime: "application/pdf",
                data: Data([0x25, 0x50, 0x44, 0x46])
            )
        )

        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["document.pdf"])
        XCTAssertTrue(viewModel.canSave)
    }

    func testCreateNoteViewSourceUsesInlineNavigationTitleOnly() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertFalse(source.contains("ToolbarItem(placement: .principal)"))
        XCTAssertTrue(source.contains("notes.create.title"))
        XCTAssertTrue(source.contains(".navigationBarTitleDisplayMode(.inline)"))
    }

    func testCreateNoteViewSourceHasTitleFormSection() throws {
        let source = try Self.createNoteViewSource()
        let formSection = source.components(separatedBy: ".toolbar").first ?? source

        XCTAssertTrue(formSection.contains("TextField("))
        XCTAssertTrue(formSection.contains("$viewModel.title"))
    }

    func testCreateNoteViewSourceDisablesSaveWhenCannotSave() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains(".disabled(!viewModel.canSave)"))
    }

    func testCreateNoteViewSourceIncludesPhotosPicker() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains("PhotosPicker("))
        XCTAssertTrue(source.contains("viewModel.addAttachment("))
        XCTAssertTrue(source.contains("notes.create.addPhoto"))
    }

    func testCreateNoteViewSourceIncludesFileImporter() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains(".fileImporter("))
        XCTAssertTrue(source.contains("importFile(from: url)"))
        XCTAssertTrue(source.contains("notes.create.addFile"))
        XCTAssertTrue(source.contains("NoteAttachmentImportSupport.fileImporterAllowedTypes"))
    }

    func testCreateNoteViewSourceUsesSharedAttachmentsSection() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains("NoteAttachmentsSection("))
        XCTAssertTrue(source.contains("viewModel.attachmentItems"))
        XCTAssertTrue(source.contains("viewModel.removeAttachment(id:)"))
        XCTAssertTrue(source.contains("viewModel.attachmentData(for:)"))
        XCTAssertTrue(source.contains("attachmentPreview($attachmentPreview)"))
    }

    func testCreateNoteViewSourceShowsInlineStates() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains("viewModel.isLoading"))
        XCTAssertTrue(source.contains("viewModel.errorMessage"))
    }

    func testCreateNoteViewSourceUsesLocalizedStrings() throws {
        let source = try Self.createNoteViewSource()

        XCTAssertTrue(source.contains("notes.create.title"))
        XCTAssertTrue(source.contains("NotesFlowUILocalization.localized"))
    }

    @MainActor
    private func makeViewModel(
        noteRepository: MockNoteRepository = MockNoteRepository(),
        navigator: MockNavigating? = nil
    ) -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(),
            navigator: navigator ?? MockNavigating()
        )
    }

    private static func createNoteViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/CreateNoteView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
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

    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        _ = noteID
        _ = recipientEmail
        _ = wrappedFEK
        throw NoteRepositoryError.notSupported
    }

    func listSharedNotes() async throws -> [SharedNoteSummary] {
        []
    }

    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

}

private actor MockVaultSession: VaultSessionProtocol {
    var isActive: Bool { true }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data(repeating: 0x01, count: 32) }
}
