import Foundation
import NoteRepositoryProtocol
import Observation
import SecureCrypto
import VaultSessionProtocol

@MainActor
public protocol SharedNoteDetailViewModel: Observable {
    var noteID: UUID { get }
    var ownerEmail: String { get }
    var title: String { get }
    var body: String { get }
    var attachmentItems: [NoteAttachmentItem] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func load() async
    func attachmentData(for id: String) -> Data?
}

@MainActor
@Observable
public final class DefaultSharedNoteDetailViewModel: SharedNoteDetailViewModel {
    public let noteID: UUID
    public private(set) var ownerEmail = ""
    public private(set) var title = ""
    public private(set) var body = ""
    public private(set) var attachmentItems: [NoteAttachmentItem] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private var attachments: [NotePayload.Attachment] = []
    private var didLoad = false

    public init(
        noteID: UUID,
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol
    ) {
        self.noteID = noteID
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
    }

    public func load() async {
        if didLoad { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let sharedNoteTask = noteRepository.readSharedNote(noteID: noteID)
            async let summariesTask = noteRepository.listSharedNotes()
            let shared = try await sharedNoteTask
            let summaries = try await summariesTask
            ownerEmail = summaries.first { $0.noteID == noteID }?.ownerEmail ?? ""

            let identityKey = try await vaultSession.identityPrivateKey()
            let fek = try unwrapSharedFEK(shared.recipientWrappedFEK, identityPrivateKey: identityKey)
            let payload = try decryptPayload(shared.encryptedPayload, with: fek)

            title = shared.metadata.title
            body = String(data: payload.body, encoding: .utf8) ?? ""
            attachments = payload.attachments
            attachmentItems = attachments.map(\.attachmentItem)
            didLoad = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func attachmentData(for id: String) -> Data? {
        attachments.first { $0.id == id }?.data
    }
}
