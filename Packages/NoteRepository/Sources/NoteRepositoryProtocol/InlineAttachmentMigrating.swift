import CryptoKit
import Foundation

/// Optional capability for repositories that can migrate v1 inline attachments to split storage.
public protocol InlineAttachmentMigrating: Sendable {
    func migrateInlineAttachmentsToSplit(noteID: UUID, fek: SymmetricKey) async throws
}
