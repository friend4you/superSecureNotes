import AuthFlowDomainProtocol
import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

@MainActor
public final class DefaultEstablishVaultSessionUseCase: EstablishVaultSessionUseCase {
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let notesIndexStore: any NotesIndexStoreProtocol
    private let noteSync: any NoteSyncing

    public init(
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        notesIndexStore: any NotesIndexStoreProtocol,
        noteSync: any NoteSyncing
    ) {
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.notesIndexStore = notesIndexStore
        self.noteSync = noteSync
    }

    public func execute(
        headerData: Data,
        password: String,
        policy: EstablishVaultSessionPolicy
    ) async throws {
        let unlockOutcome = try vaultAuthenticator.unlockVault(
            headerData: headerData,
            password: password
        )

        switch policy {
        case .firstLoginWithRemoteHeader:
            try await openIndex(sessionKeys: unlockOutcome.sessionKeys)
            do {
                try await noteSync.pullRemoteNotesCatalog()
                try await noteSync.pullRemoteSharedCatalog()
            } catch {
                await notesIndexStore.close()
                throw error
            }
            await vaultSession.establish(unlockOutcome.sessionKeys)
        case .afterLocalCreate, .standardUnlock:
            try await openAfterEstablish(
                sessionKeys: unlockOutcome.sessionKeys
            )
        }
    }

    private func openIndex(sessionKeys: VaultSessionKeys) async throws {
        let passphrase = deriveNotesDatabaseKey(from: sessionKeys.udk)
        try await notesIndexStore.open(passphrase: passphrase)
    }

    private func openAfterEstablish(sessionKeys: VaultSessionKeys) async throws {
        await vaultSession.establish(sessionKeys)
        do {
            try await openIndex(sessionKeys: sessionKeys)
        } catch {
            await vaultSession.clear()
            throw error
        }
    }
}
