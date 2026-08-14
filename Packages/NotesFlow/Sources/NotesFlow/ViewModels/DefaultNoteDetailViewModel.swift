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
    var attachmentProgressByID: [String: AttachmentRowProgress] { get }
    var hasChanges: Bool { get }
    var canSave: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var syncState: NoteSyncState { get }

    func load() async
    func addAttachment(_ attachment: NotePayload.Attachment)
    func removeAttachment(id: String)
    func attachmentData(for id: String) -> Data?
    func retryAttachment(id: String) async
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
    public private(set) var attachmentProgressByID: [String: AttachmentRowProgress] = [:]
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var syncState: NoteSyncState = .pendingSync

    public var hasChanges: Bool {
        title != loadedTitle
            || body != loadedBody
            || attachmentsDifferFromLoaded
    }

    public var canSave: Bool {
        hasChanges
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && syncState == .synced
    }

    private let noteRepository: any NoteRepository
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any Navigating
    private let noteSync: any NoteSyncing
    private var loadedTitle = ""
    private var loadedBody = ""
    private var attachments: [NotePayload.Attachment] = []
    private var loadedAttachments: [NotePayload.Attachment] = []
    private var attachmentPlaintexts: [String: Data] = [:]
    private var createdAt: UInt64 = 0
    private var fek: SymmetricKey?
    private var didLoad = false
    private nonisolated(unsafe) var syncOutcomeObservation: Task<Void, Never>?
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
        syncOutcomeObservation = Task { @MainActor [weak self] in
            guard let self else { return }
            for await outcome in noteSync.syncOutcomes {
                handleSyncOutcome(outcome)
            }
        }
        hydrationObservation = Task { @MainActor [weak self] in
            guard let self else { return }
            for await progress in noteSync.attachmentHydrationProgress {
                handleHydrationProgress(progress)
            }
        }
    }

    deinit {
        syncOutcomeObservation?.cancel()
        hydrationObservation?.cancel()
        hydrationTask?.cancel()
    }

    public func load() async {
        if didLoad {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var storedNote = try await noteRepository.readNote(noteID: noteID)
            let udk = try await vaultSession.udk()
            let loadedFEK = try unwrapFEK(storedNote.wrappedFEK, with: udk)

            if storedNoteHasInlineAttachments(storedNote, fek: loadedFEK),
               let migrator = noteRepository as? any InlineAttachmentMigrating {
                try await migrator.migrateInlineAttachmentsToSplit(noteID: noteID, fek: loadedFEK)
                storedNote = try await noteRepository.readNote(noteID: noteID)
            }

            let payload = try decryptPayload(storedNote.encryptedPayload, with: loadedFEK)

            fek = loadedFEK
            createdAt = storedNote.metadata.createdAt
            title = storedNote.metadata.title
            body = String(data: payload.body, encoding: .utf8) ?? ""
            attachments = payload.attachments
            loadedAttachments = payload.attachments
            applyPlaintexts(from: payload)
            applyCiphertexts(storedNote.attachmentCiphertexts, fek: loadedFEK)
            syncAttachmentItems()
            loadedTitle = title
            loadedBody = body
            syncState = storedNote.syncState
            didLoad = true
            isLoading = false

            hydrationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await noteSync.hydrateAttachments(noteID: noteID)
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    public func addAttachment(_ attachment: NotePayload.Attachment) {
        attachments.append(attachment)
        if let data = attachment.data {
            attachmentPlaintexts[attachment.id] = data
        }
        syncAttachmentItems()
    }

    public func removeAttachment(id: String) {
        attachments.removeAll { $0.id == id }
        attachmentPlaintexts.removeValue(forKey: id)
        attachmentProgressByID.removeValue(forKey: id)
        syncAttachmentItems()
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
        await noteSync.retryAttachment(noteID: noteID, attachmentID: attachmentID)
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
            let existingNote = try await noteRepository.readNote(noteID: noteID)
            let (payload, ciphertexts) = try makeSplitWritePayload(
                fek: fek,
                existingCiphertexts: existingNote.attachmentCiphertexts
            )
            let encryptedPayload = try encryptPayload(payload, with: fek)
            let wrappedFEK = try wrapFEK(fek, with: udk)
            let updatedAt = UInt64(Date().timeIntervalSince1970)
            let metadata = NoteMetadata(
                noteID: noteID,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attachmentCount: UInt32(payload.attachments.count),
                attachmentsTotalSize: payload.attachments.reduce(0) { $0 + UInt64($1.size) }
            )
            let storedNote = StoredNote(
                metadata: metadata,
                wrappedFEK: wrappedFEK,
                encryptedPayload: encryptedPayload,
                syncState: .pendingSync,
                attachmentCiphertexts: ciphertexts
            )
            try await noteRepository.writeNote(storedNote)
            noteSync.scheduleFlush()

            attachments = payload.attachments
            loadedTitle = title
            loadedBody = body
            loadedAttachments = payload.attachments
            syncState = .pendingSync
            syncAttachmentItems()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func handleSyncOutcome(_ outcome: NoteSyncOutcome) {
        guard case let .uploaded(outcomeNoteID, syncState, _, _) = outcome,
              outcomeNoteID == noteID else {
            return
        }
        self.syncState = syncState
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
            let storedNote = try await noteRepository.readNote(noteID: noteID)
            if let ciphertext = storedNote.attachmentCiphertexts[attachmentID] {
                let plaintext = try decryptAttachmentFile(ciphertext, with: fek)
                attachmentPlaintexts[attachmentID.uuidString] = plaintext
            }
        } catch {
            return
        }
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
                || current.size != loaded.size
                || current.data != loaded.data {
                return true
            }
        }

        return false
    }

    private func makeSplitWritePayload(
        fek: SymmetricKey,
        existingCiphertexts: [UUID: Data]
    ) throws -> (NotePayload, [UUID: Data]) {
        var index: [NotePayload.Attachment] = []
        var ciphertexts: [UUID: Data] = [:]

        for attachment in attachments {
            guard let attachmentID = UUID(uuidString: attachment.id) else {
                throw NoteRepositoryError.validationError("Attachment id must be a UUID.")
            }
            guard let plaintext = attachment.data ?? attachmentPlaintexts[attachment.id] else {
                throw NoteRepositoryError.validationError(
                    "Missing attachment bytes for '\(attachment.filename)'."
                )
            }
            let loadedAttachment = loadedAttachments.first { $0.id == attachment.id }
            let ciphertext: Data
            if let loadedAttachment,
               attachmentMetadataMatches(loadedAttachment, attachment),
               let existing = existingCiphertexts[attachmentID]
            {
                ciphertext = existing
            } else {
                ciphertext = try encryptAttachmentFile(plaintext, with: fek)
            }
            ciphertexts[attachmentID] = ciphertext
            attachmentPlaintexts[attachment.id] = plaintext
            index.append(
                NotePayload.Attachment(
                    id: attachment.id,
                    filename: attachment.filename,
                    mime: attachment.mime,
                    size: plaintext.count
                )
            )
        }

        let payload = NotePayload(
            body: Data(body.utf8),
            attachments: index,
            schemaVersion: 2
        )
        return (payload, ciphertexts)
    }

    private func attachmentMetadataMatches(
        _ loaded: NotePayload.Attachment,
        _ current: NotePayload.Attachment
    ) -> Bool {
        loaded.id == current.id
            && loaded.filename == current.filename
            && loaded.mime == current.mime
            && loaded.size == current.size
    }

    private func applyPlaintexts(from payload: NotePayload) {
        for attachment in payload.attachments {
            if let data = attachment.data {
                attachmentPlaintexts[attachment.id] = data
            }
        }
    }

    private func applyCiphertexts(_ ciphertexts: [UUID: Data], fek: SymmetricKey) {
        for (attachmentID, ciphertext) in ciphertexts {
            if let plaintext = try? decryptAttachmentFile(ciphertext, with: fek) {
                attachmentPlaintexts[attachmentID.uuidString] = plaintext
            }
        }
    }

    private func storedNoteHasInlineAttachments(_ note: StoredNote, fek: SymmetricKey) -> Bool {
        guard let payload = try? decryptPayload(note.encryptedPayload, with: fek) else {
            return false
        }
        return payload.attachments.contains { $0.data != nil }
    }

    private func syncAttachmentItems() {
        attachmentItems = attachments.map(\.attachmentItem)
    }
}
