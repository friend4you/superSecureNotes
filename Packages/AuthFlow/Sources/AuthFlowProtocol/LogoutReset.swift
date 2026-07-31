import AuthRepositoryProtocol
import CredentialStoreProtocol
import NoteRepositoryProtocol
import VaultSessionProtocol

public enum LogoutReset {
    public static func perform(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        credentialStore: any CredentialStore
    ) async {
        await notesIndexStore.close()
        try? await authRepository.logout()
        try? credentialStore.clearAll()
        await vaultSession.clear()
    }
}
