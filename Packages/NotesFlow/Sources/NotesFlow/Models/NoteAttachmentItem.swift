import Foundation
import SecureCrypto

public struct NoteAttachmentItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let mime: String

    public init(id: String, filename: String, mime: String) {
        self.id = id
        self.filename = filename
        self.mime = mime
    }
}

extension NotePayload.Attachment {
    var attachmentItem: NoteAttachmentItem {
        NoteAttachmentItem(id: id, filename: filename, mime: mime)
    }
}
