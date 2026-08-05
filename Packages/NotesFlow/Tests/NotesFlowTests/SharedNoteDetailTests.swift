import CryptoKit
import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
final class SharedNoteDetailTests: XCTestCase {
    func testLoadDecryptsSharedNoteContentAndOwnerEmail() async throws {
        let noteID = UUID()
        let identity = generateIdentityKeyPair()
        let shared = try NoteViewModelTestSupport.makeSharedNote(
            noteID: noteID,
            title: "Shared title",
            body: "Shared body",
            recipientPublicKey: identity.publicKey
        )
        let summary = SharedNoteSummary(
            noteID: noteID,
            title: "Shared title",
            updatedAt: shared.metadata.updatedAt,
            etag: "etag",
            ownerEmail: "owner@example.com",
            ownerID: UUID(),
            sharedAt: Date()
        )
        let noteRepository = SharedDetailMockNoteRepository(
            sharedNote: shared,
            sharedSummaries: [summary]
        )
        let vaultSession = SharedDetailMockVaultSession(identityPrivateKey: identity.privateKey)
        let viewModel = DefaultSharedNoteDetailViewModel(
            noteID: noteID,
            noteRepository: noteRepository,
            vaultSession: vaultSession
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.title, "Shared title")
        XCTAssertEqual(viewModel.body, "Shared body")
        XCTAssertEqual(viewModel.ownerEmail, "owner@example.com")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSharedNoteDetailViewSourceIsReadOnly() throws {
        let source = try Self.sharedNoteDetailViewSource()
        XCTAssertTrue(source.contains("notes.shared.detail.owner"))
        XCTAssertTrue(source.contains("viewModel.ownerEmail"))
        XCTAssertFalse(source.contains("common.save"))
        XCTAssertFalse(source.contains("TextField("))
        XCTAssertFalse(source.contains("TextEditor("))
        XCTAssertTrue(source.contains("allowsRemoval: false"))
    }

    private static func sharedNoteDetailViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/NotesFlow/SharedNoteDetailView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private actor SharedDetailMockNoteRepository: NoteRepository {
    private let sharedNote: SharedNote
    private let sharedSummaries: [SharedNoteSummary]

    init(sharedNote: SharedNote, sharedSummaries: [SharedNoteSummary]) {
        self.sharedNote = sharedNote
        self.sharedSummaries = sharedSummaries
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
    func listSharedNotes() async throws -> [SharedNoteSummary] { sharedSummaries }
    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        guard sharedNote.noteID == noteID else {
            throw NoteRepositoryError.noteNotFound
        }
        return sharedNote
    }
}

private actor SharedDetailMockVaultSession: VaultSessionProtocol {
    private let identityPrivate: Data

    init(identityPrivateKey: Data) {
        identityPrivate = identityPrivateKey
    }

    var isActive: Bool { true }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { identityPrivate }
}
