import CryptoKit
import Foundation
import NavigationProtocol
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
    var attachmentProgressByID: [String: AttachmentRowProgress] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func load() async
    func attachmentData(for id: String) -> Data?
    func retryAttachment(id: String) async
    func delete() async
}

@MainActor
@Observable
public final class DefaultSharedNoteDetailViewModel: SharedNoteDetailViewModel {
    public let noteID: UUID
    public private(set) var ownerEmail = ""
    public private(set) var title = ""
    public private(set) var body = ""
    public private(set) var attachmentItems: [NoteAttachmentItem] = []
    public private(set) var attachmentProgressByID: [String: AttachmentRowProgress] = [:]
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating
    private let noteSync: any NoteSyncing
    private var attachments: [NotePayload.Attachment] = []
    private var attachmentPlaintexts: [String: Data] = [:]
    private var fek: SymmetricKey?
    private var didLoad = false
    private nonisolated(unsafe) var hydrationObservation: Task<Void, Never>?
    private nonisolated(unsafe) var hydrationTask: Task<Void, Never>?

    public init(
        noteID: UUID,
        noteRepository: any NoteRepository,
        vaultSession: any VaultSessionProtocol,
        navigator: any Navigating,
        noteSync: any NoteSyncing = NoOpNoteSyncService()
    ) {
        self.noteID = noteID
        self.noteRepository = noteRepository
        self.vaultSession = vaultSession
        self.navigator = navigator
        self.noteSync = noteSync
        hydrationObservation = Task { @MainActor [weak self] in
            guard let self else { return }
            for await progress in noteSync.attachmentHydrationProgress {
                handleHydrationProgress(progress)
            }
        }
    }

    deinit {
        hydrationObservation?.cancel()
        hydrationTask?.cancel()
    }

    public func load() async {
        if didLoad { return }

        isLoading = true
        errorMessage = nil

        do {
            let shared = try await noteRepository.readSharedNote(noteID: noteID)
            let summary = try await noteRepository.fetchSharedNoteSummary(noteID: noteID)
            ownerEmail = summary?.ownerEmail ?? ""

            let identityKey = try await vaultSession.identityPrivateKey()
            let loadedFEK = try unwrapSharedFEK(shared.recipientWrappedFEK, identityPrivateKey: identityKey)
            let payload = try decryptPayload(shared.encryptedPayload, with: loadedFEK)

            fek = loadedFEK
            title = shared.metadata.title
            body = String(data: payload.body, encoding: .utf8) ?? ""
            attachments = payload.attachments
            for attachment in payload.attachments {
                if let data = attachment.data {
                    attachmentPlaintexts[attachment.id] = data
                }
            }
            let ciphertexts = try await noteRepository.loadSharedAttachmentCiphertexts(noteID: noteID)
                applyCiphertexts(ciphertexts, fek: loadedFEK)
            attachmentItems = attachments.map(\.attachmentItem)
            didLoad = true
            isLoading = false

            hydrationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await noteSync.hydrateSharedAttachments(noteID: noteID)
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    public func attachmentData(for id: String) -> Data? {
        attachments.first { $0.id == id }.flatMap(\.data) ?? attachmentPlaintexts[id]
    }

    public func retryAttachment(id: String) async {
        guard let attachmentID = UUID(uuidString: id) else { return }
        attachmentProgressByID[id] = AttachmentRowProgress(
            bytesReceived: 0,
            totalBytes: attachmentProgressByID[id]?.totalBytes ?? 0,
            state: .downloading
        )
        await noteSync.retrySharedAttachment(noteID: noteID, attachmentID: attachmentID)
    }

    public func delete() async {
        isLoading = true
        errorMessage = nil

        do {
            try await noteRepository.deleteSharedNote(noteID: noteID)
            navigator.pop()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleHydrationProgress(_ progress: AttachmentHydrationProgress) {
        guard progress.noteID == noteID else { return }
        let key = progress.attachmentID.uuidString
        switch progress.state {
        case .downloading, .failed:
            attachmentProgressByID[key] = AttachmentRowProgress(progress)
        case .completed:
            attachmentProgressByID.removeValue(forKey: key)
            Task { @MainActor [weak self] in
                await self?.refreshAttachmentPlaintext(attachmentID: progress.attachmentID)
            }
        }
    }

    private func refreshAttachmentPlaintext(attachmentID: UUID) async {
        guard let fek else { return }
        do {
            if let ciphertext = try await noteRepository.readSharedAttachmentCiphertext(
                noteID: noteID,
                attachmentID: attachmentID
            ) {
                let plaintext = try decryptAttachmentFile(ciphertext, with: fek)
                attachmentPlaintexts[attachmentID.uuidString] = plaintext
            }
        } catch {
            return
        }
    }

    private func applyCiphertexts(_ ciphertexts: [UUID: Data], fek: SymmetricKey) {
        for (attachmentID, ciphertext) in ciphertexts {
            if let plaintext = try? decryptAttachmentFile(ciphertext, with: fek) {
                attachmentPlaintexts[attachmentID.uuidString] = plaintext
            }
        }
    }
}
