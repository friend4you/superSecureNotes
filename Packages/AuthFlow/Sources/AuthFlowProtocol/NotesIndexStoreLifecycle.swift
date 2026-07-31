import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

enum NotesIndexStoreLifecycle {
    static func openAfterEstablish(
        sessionKeys: VaultSessionKeys,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol
    ) async throws {
        await vaultSession.establish(sessionKeys)
        let passphrase = deriveNotesDatabaseKey(from: sessionKeys.udk)
        do {
            try await notesIndexStore.open(passphrase: passphrase)
        } catch {
            await vaultSession.clear()
            throw error
        }
    }
}
