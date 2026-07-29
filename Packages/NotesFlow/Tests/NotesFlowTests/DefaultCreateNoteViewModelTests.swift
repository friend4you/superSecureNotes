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
final class DefaultCreateNoteViewModelTests: XCTestCase {
    func testCanSaveRequiresNonEmptyTitle() {
        let viewModel = makeViewModel()
        viewModel.body = "Some body"

        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "   "
        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "My note"
        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveRequiresChangesFromInitialEmptyState() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "Title only"
        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveWithTitleAndBody() {
        let viewModel = makeViewModel()
        viewModel.title = "Title"
        viewModel.body = "Body"

        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSaveWithTitleAndAttachment() {
        let viewModel = makeViewModel()
        viewModel.title = "Title"
        viewModel.addAttachment(sampleAttachment(filename: "photo.png"))

        XCTAssertTrue(viewModel.canSave)
    }

    func testAddAttachmentPublishesAttachmentItems() {
        let viewModel = makeViewModel()

        viewModel.addAttachment(sampleAttachment(id: "1", filename: "photo.png", mime: "image/png"))
        viewModel.addAttachment(sampleAttachment(id: "2", filename: "notes.pdf", mime: "application/pdf"))

        XCTAssertEqual(viewModel.attachmentItems.map(\.id), ["1", "2"])
        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["photo.png", "notes.pdf"])
        XCTAssertEqual(viewModel.attachmentItems.map(\.mime), ["image/png", "application/pdf"])
    }

    func testRemoveAttachmentRemovesByID() {
        let viewModel = makeViewModel()
        viewModel.addAttachment(sampleAttachment(id: "keep", filename: "keep.txt"))
        viewModel.addAttachment(sampleAttachment(id: "remove", filename: "remove.txt"))

        viewModel.removeAttachment(id: "remove")

        XCTAssertEqual(viewModel.attachmentItems.map(\.filename), ["keep.txt"])
    }

    func testAttachmentDataReturnsBytesForValidID() {
        let viewModel = makeViewModel()
        let attachment = sampleAttachment(id: "data-id", filename: "file.bin", data: Data([0xAB, 0xCD]))
        viewModel.addAttachment(attachment)

        XCTAssertEqual(viewModel.attachmentData(for: "data-id"), Data([0xAB, 0xCD]))
        XCTAssertNil(viewModel.attachmentData(for: "missing"))
    }

    func testSaveWritesNewNoteAndPops() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteRepository = MockNoteRepository()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(
            noteRepository: noteRepository,
            vaultSession: MockVaultSession(udk: udk),
            navigator: navigator
        )
        viewModel.title = "New note"
        viewModel.body = "New body"
        viewModel.addAttachment(sampleAttachment(filename: "image.png"))

        await viewModel.save()

        let writtenNotes = await noteRepository.writtenNotes
        XCTAssertEqual(writtenNotes.count, 1)
        XCTAssertEqual(navigator.popCount, 1)
        XCTAssertNil(viewModel.errorMessage)

        let (noteID, data) = writtenNotes[0]
        let sections = try parseNoteFile(data)
        XCTAssertEqual(sections.metadata.noteID, noteID)
        XCTAssertEqual(sections.metadata.title, "New note")
        let fek = try unwrapFEK(sections.wrappedFEK, with: udk)
        let payload = try decryptPayload(sections.encryptedPayload, with: fek)
        XCTAssertEqual(String(data: payload.body, encoding: .utf8), "New body")
        XCTAssertEqual(payload.attachments.map(\.filename), ["image.png"])
    }

    func testSaveDoesNothingWhenCannotSave() async {
        let noteRepository = MockNoteRepository()
        let navigator = MockNavigating()
        let viewModel = makeViewModel(
            noteRepository: noteRepository,
            navigator: navigator
        )

        await viewModel.save()

        let writtenNotes = await noteRepository.writtenNotes
        XCTAssertTrue(writtenNotes.isEmpty)
        XCTAssertEqual(navigator.popCount, 0)
    }

    @MainActor
    private func makeViewModel(
        noteRepository: MockNoteRepository = MockNoteRepository(),
        vaultSession: MockVaultSession = MockVaultSession(),
        navigator: MockNavigating? = nil
    ) -> DefaultCreateNoteViewModel {
        DefaultCreateNoteViewModel(
            noteRepository: noteRepository,
            vaultSession: vaultSession,
            navigator: navigator ?? MockNavigating()
        )
    }

    private func sampleAttachment(
        id: String = UUID().uuidString,
        filename: String,
        mime: String = "application/octet-stream",
        data: Data = Data([0x01])
    ) -> NotePayload.Attachment {
        NotePayload.Attachment(
            id: id,
            filename: filename,
            mime: mime,
            data: data
        )
    }
}

private actor MockNoteRepository: NoteRepository {
    private(set) var writtenNotes: [(UUID, Data)] = []

    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }

    func writeNote(noteID: UUID, data: Data) async throws {
        writtenNotes.append((noteID, data))
    }

    func deleteNote(noteID: UUID) async throws {}
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
