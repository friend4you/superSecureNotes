import Foundation

public struct NotePayload: Codable, Equatable, Sendable {
    public struct Attachment: Codable, Equatable, Sendable {
        public let id: String
        public let filename: String
        public let mime: String
        public let data: Data

        public init(id: String, filename: String, mime: String, data: Data) {
            self.id = id
            self.filename = filename
            self.mime = mime
            self.data = data
        }
    }

    public let body: Data
    public let attachments: [Attachment]

    public init(body: Data, attachments: [Attachment] = []) {
        self.body = body
        self.attachments = attachments
    }
}
