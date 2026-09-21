#if DEBUG
import Foundation
import AuthRepositoryProtocol
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

@MainActor
final class PreviewNavigator: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}

actor PreviewAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }

    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }

    func logout() async throws {}
    func deleteAccount(password: String) async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func clearSession() async {}
}

final class PreviewCredentialStore: CredentialStore, @unchecked Sendable {
    var hasLocalSetup: Bool { false }
    func markSetupComplete() throws {}
    func saveEmail(_ email: String) throws {}
    func email() -> String? { nil }
    func saveRefreshToken(_ token: String) throws {}
    func refreshToken() -> String? { nil }
    func saveVaultHeader(_ header: Data) throws {}
    func vaultHeader() -> Data? { nil }
    func bioEnabled() -> Bool { false }
    func setBioEnabled(_ enabled: Bool) throws {}
    func savePassword(_ password: String) throws {}
    func loadPasswordWithBiometrics() throws -> String { throw CredentialStoreError.itemNotFound }
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}
    func clearAll() throws {}
}

actor PreviewVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}

actor PreviewNoteRepository: NoteRepository {
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
#endif
