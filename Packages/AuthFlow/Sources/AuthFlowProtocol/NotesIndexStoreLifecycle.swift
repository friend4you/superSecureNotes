import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

enum NotesIndexStoreLifecycle {
    static func open(
        sessionKeys: VaultSessionKeys,
        notesIndexStore: any NotesIndexStoreProtocol
    ) async throws {
        let passphrase = deriveNotesDatabaseKey(from: sessionKeys.udk)
        try await notesIndexStore.open(passphrase: passphrase)
    }

    static func establish(
        sessionKeys: VaultSessionKeys,
        vaultSession: any VaultSessionProtocol
    ) async {
        await vaultSession.establish(sessionKeys)
    }

    static func openAfterEstablish(
        sessionKeys: VaultSessionKeys,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol
    ) async throws {
        await vaultSession.establish(sessionKeys)
        do {
            try await open(sessionKeys: sessionKeys, notesIndexStore: notesIndexStore)
        } catch {
            await vaultSession.clear()
            throw error
        }
    }
}
