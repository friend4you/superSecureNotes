import AuthRepositoryProtocol
import CredentialStoreProtocol
import VaultSessionProtocol

public enum LogoutReset {
    public static func perform(
        authRepository: any AuthRepository,
        vaultSession: any VaultSessionProtocol,
        credentialStore: any CredentialStore
    ) async {
        try? await authRepository.logout()
        await vaultSession.clear()
        try? credentialStore.clearAll()
    }
}
