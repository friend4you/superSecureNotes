import AuthRepositoryProtocol
import AuthFlowDomainProtocol
import CredentialStoreProtocol
import NoteRepositoryProtocol
import VaultSessionProtocol

public enum LogoutReset {
    public static func perform(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        credentialStore: any CredentialStore,
        sessionPasswordCache: (any SessionPasswordCaching)? = nil,
        pendingBiometricEnrollmentStore: (any PendingBiometricEnrollmentStoring)? = nil,
        localAppDataWiper: (any LocalAppDataWiping)? = nil
    ) async {
        await notesIndexStore.close()
        try? await authRepository.logout()
        try? await localAppDataWiper?.wipeAll()
        await MainActor.run {
            sessionPasswordCache?.clear()
        }
        pendingBiometricEnrollmentStore?.setPending(false)
        try? credentialStore.clearAll()
        await vaultSession.clear()
    }
}
