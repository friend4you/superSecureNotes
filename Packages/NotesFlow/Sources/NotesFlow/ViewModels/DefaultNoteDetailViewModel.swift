import CryptoKit
import Foundation
import NavigationProtocol
import NoteRepositoryProtocol
import Observation
import SecureCrypto
import ShareNoteRoutes
import VaultSessionProtocol

@MainActor
public protocol NoteDetailViewModel: Observable {
    var noteID: UUID { get }
    var title: String { get set }
    var body: String { get set }
    var attachmentItems: [NoteAttachmentItem] { get }
    var hasChanges: Bool { get }
    var canSave: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func load() async
    func addAttachment(_ attachment: NotePayload.Attachment)
    func removeAttachment(id: String)
    func attachmentData(for id: String) -> Data?
    func reportError(_ message: String)
    func save() async
    func share()
    func delete() async
}

@MainActor
@Observable
public final class DefaultNoteDetailViewModel: NoteDetailViewModel {
    public let noteID: UUID
    public var title = ""
    public var body = ""
    public private(set) var attachmentItems: [NoteAttachmentItem] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public var hasChanges: Bool {
        title != loadedTitle
            || body != loadedBody
            || attachmentsDifferFromLoaded
    }

    public var canSave: Bool {
        hasChanges && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating
    private var loadedTitle = ""
    private var loadedBody = ""
    private var attachments: [NotePayload.Attachment] = []
    private var loadedAttachments: [NotePayload.Attachment] = []
    private var createdAt: UInt64 = 0
    private var fek: SymmetricKey?

    public init(
        noteID: UUID,
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating
    ) {
        self.noteID = noteID
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await noteRepository.readNote(noteID: noteID)
            let udk = try await vaultSession.udk()
            let sections = try parseNoteFile(data)
            let loadedFEK = try unwrapFEK(sections.wrappedFEK, with: udk)
            let payload = try decryptPayload(sections.encryptedPayload, with: loadedFEK)

            fek = loadedFEK
            createdAt = sections.metadata.createdAt
            title = sections.metadata.title
            body = String(data: payload.body, encoding: .utf8) ?? ""
            attachments = payload.attachments
            loadedAttachments = payload.attachments
            syncAttachmentItems()
            loadedTitle = title
            loadedBody = body
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
        guard canSave, let fek else { return }

        isLoading = true
        errorMessage = nil

        do {
            let udk = try await vaultSession.udk()
            let payload = NotePayload(body: Data(body.utf8), attachments: attachments)
            let encryptedPayload = try encryptPayload(payload, with: fek)
            let wrappedFEK = try wrapFEK(fek, with: udk)
            let updatedAt = UInt64(Date().timeIntervalSince1970)
            let metadata = NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attachmentCount: UInt32(attachments.count),
                attachmentsTotalSize: attachments.reduce(0) { $0 + UInt64($1.data.count) }
            )
            let data = try assembleNoteFile(
                metadata: metadata,
                wrappedFEK: wrappedFEK,
                encryptedPayload: encryptedPayload
            )
            try await noteRepository.writeNote(noteID: noteID, data: data)

            loadedTitle = title
            loadedBody = body
            loadedAttachments = attachments
            syncAttachmentItems()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func share() {
        navigator.present(ShareNoteRoute.share(noteID: noteID), style: .sheet)
    }

    public func delete() async {
        isLoading = true
        errorMessage = nil

        do {
            try await noteRepository.deleteNote(noteID: noteID)
            navigator.pop()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private var attachmentsDifferFromLoaded: Bool {
        guard attachments.count == loadedAttachments.count else { return true }

        for (current, loaded) in zip(attachments, loadedAttachments) {
            if current.id != loaded.id
                || current.filename != loaded.filename
                || current.mime != loaded.mime
                || current.data != loaded.data {
                return true
            }
        }

        return false
    }

    private func syncAttachmentItems() {
        attachmentItems = attachments.map(\.attachmentItem)
    }
}
