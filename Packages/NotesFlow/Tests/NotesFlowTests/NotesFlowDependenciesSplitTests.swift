import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import VaultSessionProtocol
import XCTest

@testable import NotesFlow

@MainActor
private final class MockNavigating: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

@MainActor
final class NotesFlowDependenciesSplitTests: XCTestCase {
    func testDetailViewModelReceivesHydrationProgressFromInjectedSyncService() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let udk = SymmetricKey(size: .bits256)
        let (noteData, _) = try NoteViewModelTestSupport.makeSplitStoredNote(
            noteID: noteID,
            title: "Hydration",
            body: "Body",
            udk: udk,
            attachmentPlaintexts: [
                (attachmentID, "file.bin", "application/octet-stream", Data([0x01])),
            ],
            syncState: .synced
        )
        let coldNote = StoredNote(
            metadata: noteData.metadata,
            wrappedFEK: noteData.wrappedFEK,
            encryptedPayload: noteData.encryptedPayload,
            syncState: .synced,
            attachmentCiphertexts: [:]
        )
        let noteSync = ControllableNoteSyncService()
        let hydrationStarted = expectation(description: "hydrateAttachments started")
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: StoredNoteMockVaultSession(udk: udk),
            navigator: MockNavigating(),
            noteRepository: StoredNoteMockRepository(notes: [noteID: coldNote]),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        await noteSync.setHydrateAttachmentsHandler { id in
            XCTAssertEqual(id, noteID)
            hydrationStarted.fulfill()
            await noteSync.emitHydration(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    bytesReceived: 1,
                    totalBytes: 3,
                    state: .downloading
                )
            )
        }

        let viewModel = dependencies.makeNoteDetailViewModel(noteID: noteID)
        await viewModel.load()

        await fulfillment(of: [hydrationStarted], timeout: 1.0)
        try? await Task.sleep(nanoseconds: 80_000_000)

        let progress = try XCTUnwrap(viewModel.attachmentProgressByID[attachmentID.uuidString])
        XCTAssertEqual(progress.state, .downloading)
        XCTAssertEqual(progress.bytesReceived, 1)
        XCTAssertEqual(progress.totalBytes, 3)
        let hydrateCount = await noteSync.hydrateAttachmentsCallCount
        XCTAssertEqual(hydrateCount, 1)
    }

    func testSharedDetailViewModelReceivesHydrationProgressFromInjectedSyncService() async throws {
        let noteID = UUID()
        let attachmentID = UUID()
        let identity = generateIdentityKeyPair()
        let shared = try NoteViewModelTestSupport.makeSharedNote(
            noteID: noteID,
            title: "Shared hydration",
            body: "Shared body",
            recipientPublicKey: identity.publicKey,
            attachments: [
                NotePayload.Attachment(
                    id: attachmentID.uuidString,
                    filename: "shared.bin",
                    mime: "application/octet-stream",
                    size: 1
                ),
            ],
            schemaVersion: 2
        )
        let noteSync = ControllableNoteSyncService()
        let dependencies = NotesFlowDependencies(
            authRepository: MockAuthRepository(),
            vaultSession: SplitTestSharedVaultSession(identityPrivateKey: identity.privateKey),
            navigator: MockNavigating(),
            noteRepository: SplitTestSharedNoteRepository(sharedNote: shared),
            credentialStore: NotesFlowTestMocks.credentialStore(),
            noteSync: noteSync,
            performLogout: NotesFlowTestMocks.noopLogout
        )

        await noteSync.setHydrateSharedAttachmentsHandler { id in
            XCTAssertEqual(id, noteID)
            await noteSync.emitHydration(
                AttachmentHydrationProgress(
                    noteID: noteID,
                    attachmentID: attachmentID,
                    bytesReceived: 1,
                    totalBytes: 2,
                    state: .downloading
                )
            )
        }

        let viewModel = dependencies.makeSharedNoteDetailViewModel(noteID: noteID)
        await viewModel.load()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let progress = try XCTUnwrap(viewModel.attachmentProgressByID[attachmentID.uuidString])
        XCTAssertEqual(progress.bytesReceived, 1)
        XCTAssertEqual(progress.totalBytes, 2)
        let hydrateCount = await noteSync.hydrateSharedAttachmentsCallCount
        XCTAssertEqual(hydrateCount, 1)
    }
}

private actor MockAuthRepository: AuthRepository {
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

private actor SplitTestSharedNoteRepository: NoteRepository {
    private let sharedNote: SharedNote

    init(sharedNote: SharedNote) {
        self.sharedNote = sharedNote
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
    func listSharedNotes() async throws -> [SharedNoteSummary] { [] }
    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        guard sharedNote.noteID == noteID else {
            throw NoteRepositoryError.noteNotFound
        }
        return sharedNote
    }
    func deleteSharedNote(noteID: UUID) async throws {
        throw NoteRepositoryError.notSupported
    }
}

private actor SplitTestSharedVaultSession: VaultSessionProtocol {
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
