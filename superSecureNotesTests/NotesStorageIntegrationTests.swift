import AuthFlowProtocol
import AuthRepositoryProtocol
import CryptoKit
import CredentialStoreProtocol
import NoteRepository
import NoteRepositoryProtocol
import SecureCrypto
import VaultSession
import VaultSessionProtocol
import XCTest

@testable import superSecureNotes

final class NotesStorageIntegrationTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        super.tearDown()
    }

    func testUnlockCreateNotePersistsEncryptedStorage() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440011")!
        let title = "Integration Note"
        let (indexStore, repository) = makeRepository()
        try await indexStore.open(passphrase: deriveNotesDatabaseKey(from: udk))
        try await repository.writeNote(
            try makeStoredNote(noteID: noteID, title: title, body: "Body", udk: udk)
        )

        let databaseURL = temporaryDirectory.appendingPathComponent("notes.db")
        let payloadURL = temporaryDirectory
            .appendingPathComponent(noteID.uuidString, isDirectory: true)
            .appendingPathComponent("payload")
        let payloadData = try Data(contentsOf: payloadURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertNil(payloadData.range(of: Data(title.utf8)))
    }

    func testLockAndUnlockPreservesNotes() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440012")!
        let (indexStore, repository) = makeRepository()
        let passphrase = deriveNotesDatabaseKey(from: udk)
        try await indexStore.open(passphrase: passphrase)
        try await repository.writeNote(
            try makeStoredNote(noteID: noteID, title: "Persisted", body: "After lock", udk: udk)
        )

        await indexStore.close()
        let isOpenAfterLock = await indexStore.isOpen
        XCTAssertFalse(isOpenAfterLock)

        try await indexStore.open(passphrase: passphrase)
        let summaries = try await repository.listNotes()
        let note = try await repository.readNote(noteID: noteID)

        XCTAssertEqual(summaries.map(\.title), ["Persisted"])
        XCTAssertEqual(note.metadata.title, "Persisted")
    }

    func testLogoutClosesIndexStoreAndWipesLocalNotesData() async throws {
        let udk = SymmetricKey(size: .bits256)
        let noteID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440013")!
        let vaultSession = VaultSession()
        let authRepository = TestAuthRepository()
        let credentialStore = TestCredentialStore()
        let (indexStore, repository) = makeRepository()
        let passphrase = deriveNotesDatabaseKey(from: udk)

        try await indexStore.open(passphrase: passphrase)
        try await repository.writeNote(
            try makeStoredNote(noteID: noteID, title: "Removed on logout", body: "Body", udk: udk)
        )
        await vaultSession.establish(
            VaultSessionKeys(
                udk: udk,
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )

        let databaseURL = temporaryDirectory.appendingPathComponent("notes.db")
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))

        await LogoutReset.perform(
            authRepository: authRepository,
            vaultSession: vaultSession,
            notesIndexStore: indexStore,
            credentialStore: credentialStore,
            localAppDataWiper: FileSystemLocalAppDataWiper(rootURL: temporaryDirectory)
        )

        let isOpenAfterLogout = await indexStore.isOpen
        let isActiveAfterLogout = await vaultSession.isActive
        XCTAssertFalse(isOpenAfterLogout)
        XCTAssertFalse(isActiveAfterLogout)
        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    private func makeRepository() -> (NotesIndexStore, LocalNoteRepository) {
        let indexStore = NotesIndexStore(notesDirectoryURL: temporaryDirectory)
        let repository = LocalNoteRepository(
            notesIndexStore: indexStore,
            notesRootURL: temporaryDirectory
        )
        return (indexStore, repository)
    }

    private func makeStoredNote(
        noteID: UUID,
        title: String,
        body: String,
        udk: SymmetricKey
    ) throws -> StoredNote {
        let fek = generateSymmetricKey()
        let encryptedPayload = try encryptPayload(
            NotePayload(body: Data(body.utf8)),
            with: fek
        )
        return StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: try wrapFEK(fek, with: udk),
            encryptedPayload: encryptedPayload,
            syncState: .pendingSync
        )
    }
}

private final class TestCredentialStore: CredentialStore, @unchecked Sendable {
    var hasLocalSetup = true

    func markSetupComplete() throws { hasLocalSetup = true }
    func saveEmail(_ email: String) throws {}
    func email() -> String? { "user@example.com" }
    func saveRefreshToken(_ token: String) throws {}
    func refreshToken() -> String? { "refresh-token" }
    func saveVaultHeader(_ header: Data) throws {}
    func vaultHeader() -> Data? { Data([0x01]) }
    func bioEnabled() -> Bool { false }
    func setBioEnabled(_ enabled: Bool) throws {}
    func savePassword(_ password: String) throws {}
    func loadPasswordWithBiometrics() throws -> String { throw CredentialStoreError.itemNotFound }
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {
        hasLocalSetup = true
    }
    func clearAll() throws { hasLocalSetup = false }
}

private actor TestAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.validationError("unused")
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        throw AuthRepositoryError.validationError("unused")
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
