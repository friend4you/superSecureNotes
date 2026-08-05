import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import Observation
import SecureCrypto
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
public protocol ShareNoteViewModel: Observable {
    var noteID: UUID { get }
    var recipientEmail: String { get set }
    var isSharing: Bool { get }
    var errorMessage: String? { get }
    func share() async
    func dismiss()
}

@MainActor
@Observable
public final class DefaultShareNoteViewModel: ShareNoteViewModel {
    public let noteID: UUID
    public var recipientEmail = ""
    public private(set) var isSharing = false
    public private(set) var errorMessage: String?

    private let noteRepository: any NoteRepository
    private let vaultRepository: any VaultRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating

    public init(
        noteID: UUID,
        noteRepository: any NoteRepository,
        vaultRepository: any VaultRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.noteID = noteID
        self.noteRepository = noteRepository
        self.vaultRepository = vaultRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func share() async {
        let email = recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = ShareNoteUILocalization.localized("share.error.emptyEmail")
            return
        }

        isSharing = true
        errorMessage = nil
        defer { isSharing = false }

        do {
            let storedNote = try await noteRepository.readNote(noteID: noteID)
            guard storedNote.syncState == .synced else {
                errorMessage = ShareNoteUILocalization.localized("share.error.notSynced")
                return
            }

            let udk = try await vaultSession.udk()
            let fek = try unwrapFEK(storedNote.wrappedFEK, with: udk)
            let recipientPublicKey = try await vaultRepository.fetchPublicKey(email: email)
            let wrappedForRecipient = try wrapFEKForRecipient(fek, recipientPublicKey: recipientPublicKey)
            try await noteRepository.shareNote(
                noteID: noteID,
                recipientEmail: email,
                wrappedFEK: wrappedForRecipient
            )
            navigator.dismissPresentation()
        } catch let error as VaultRepositoryError where error == .publicKeyNotFound {
            errorMessage = ShareNoteUILocalization.localized("share.error.recipientNotFound")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func dismiss() {
        navigator.dismissPresentation()
    }
}
