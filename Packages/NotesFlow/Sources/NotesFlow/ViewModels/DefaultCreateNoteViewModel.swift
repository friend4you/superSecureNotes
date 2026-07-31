import CryptoKit
import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import Observation
import SecureCrypto
import VaultSessionProtocol

@MainActor
public protocol CreateNoteViewModel: Observable {
    var title: String { get set }
    var body: String { get set }
    var attachmentItems: [NoteAttachmentItem] { get }
    var canSave: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func addAttachment(_ attachment: NotePayload.Attachment)
    func removeAttachment(id: String)
    func attachmentData(for id: String) -> Data?
    func reportError(_ message: String)
    func save() async
}

@MainActor
@Observable
public final class DefaultCreateNoteViewModel: CreateNoteViewModel {
    public var title = ""
    public var body = ""
    public private(set) var attachmentItems: [NoteAttachmentItem] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        return !title.isEmpty || !body.isEmpty || !attachments.isEmpty
    }

    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating
    private var attachments: [NotePayload.Attachment] = []

    public init(
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func addAttachment(_ attachment: NotePayload.Attachment) {
        attachments.append(attachment)
        syncAttachmentItems()
    }

    public func removeAttachment(id: String) {
        attachments.removeAll { $0.id == id }
        syncAttachmentItems()
    }

    public func attachmentData(for id: String) -> Data? {
        attachments.first { $0.id == id }?.data
    }

    public func reportError(_ message: String) {
        errorMessage = message
    }

    public func save() async {
        guard canSave else { return }

        isLoading = true
        errorMessage = nil

        do {
            let noteID = UUID()
            let fek = generateSymmetricKey()
            let udk = try await vaultSession.udk()
            let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
            let encryptedPayload = try encryptPayload(payload, with: fek)
            let wrappedFEK = try wrapFEK(fek, with: udk)
            let timestamp = UInt64(Date().timeIntervalSince1970)
            let metadata = NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: timestamp,
                updatedAt: timestamp,
                attachmentCount: UInt32(attachments.count),
                attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
            )
            let storedNote = StoredNote(
                metadata: metadata,
                wrappedFEK: wrappedFEK,
                encryptedPayload: encryptedPayload,
                syncState: .pendingSync
            )
            try await noteRepository.writeNote(storedNote)
            navigator.pop()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func syncAttachmentItems() {
        attachmentItems = attachments.map(\.attachmentItem)
    }
}
