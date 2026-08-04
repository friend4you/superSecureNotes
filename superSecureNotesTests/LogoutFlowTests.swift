import AuthFlowProtocol
import AuthFlowRoutes
import AuthRepository
import AuthRepositoryProtocol
import CredentialStore
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepository
import NoteRepositoryProtocol
import NotesFlow
import SecureCrypto
import NotesFlowRoutes
import VaultSession
import XCTest

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
final class LogoutFlowTests: XCTestCase {
    func testLogoutClosesNotesIndexStoreAndClearsSession() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let notesIndexStore = NotesIndexStore(notesDirectoryURL: temporaryDirectory)
        let udk = SymmetricKey(size: .bits256)
        try await notesIndexStore.open(passphrase: deriveNotesDatabaseKey(from: udk))

        let vaultSession = VaultSession()
        let navigator = MockNavigating()
        let credentialStore = KeychainCredentialStore(
            service: "com.superSecureNotes.tests.\(UUID().uuidString)",
            passwordAccessMode: .standard
        )
        let authRepository = TestAuthRepository()
        let viewModel = DefaultNoteListViewModel(
            authRepository: authRepository,
            vaultSession: vaultSession,
            noteRepository: MockNoteRepository(),
            navigator: navigator,
            credentialStore: credentialStore,
            performLogout: {
                await LogoutReset.perform(
                    authRepository: authRepository,
                    vaultSession: vaultSession,
                    notesIndexStore: notesIndexStore,
                    credentialStore: credentialStore
                )
            }
        )
        await vaultSession.establish(
            VaultSessionKeys(
                udk: udk,
                identityPrivateKey: Data(repeating: 0x01, count: 32)
            )
        )
        SessionRootNavigation.apply(
            hasLocalSetup: false,
            isVaultActive: true,
            to: navigator
        )

        await viewModel.logout()

        let isOpen = await notesIndexStore.isOpen
        let isActive = await vaultSession.isActive
        SessionRootNavigation.apply(
            hasLocalSetup: credentialStore.hasLocalSetup,
            isVaultActive: isActive,
            to: navigator
        )
        XCTAssertFalse(isOpen)
        XCTAssertFalse(isActive)
        XCTAssertFalse(credentialStore.hasLocalSetup)
        XCTAssertEqual(navigator.setRootRoutes.last?.base as? AuthRoute, .login)
    }
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
