import AuthRepositoryProtocol
import CredentialStoreProtocol
import NoteRepositoryProtocol
import VaultSessionProtocol

public enum LogoutReset {
    public static func perform(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        credentialStore: any CredentialStore,
        localAppDataWiper: (any LocalAppDataWiping)? = nil
    ) async {
        await notesIndexStore.close()
        try? await authRepository.logout()
        try? await localAppDataWiper?.wipeAll()
        try? credentialStore.clearAll()
        await vaultSession.clear()
    }
}
