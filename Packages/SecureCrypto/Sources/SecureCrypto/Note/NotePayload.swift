import Foundation
import SecureCryptoProtocol

public struct NotePayload: Codable, Equatable, Sendable {
    public struct Attachment: Equatable, Sendable {
        public let id: String
        public let filename: String
        public let mime: String
        /// Present for schema v1 (inline bytes). Absent for schema v2 index entries.
        public let data: Data?
        /// Byte count of the attachment file.
        public let size: Int

        /// Schema v1 attachment with inline file bytes.
        public init(id: String, filename: String, mime: String, data: Data) {
            self.id = id
            self.filename = filename
            self.mime = mime
            self.data = data
            self.size = data.count
        }

        /// Schema v2 index entry (no inline bytes).
        public init(id: String, filename: String, mime: String, size: Int) {
            self.id = id
            self.filename = filename
            self.mime = mime
            self.data = nil
            self.size = size
        }
    }

    public let schemaVersion: Int
    public let body: Data
    public let attachments: [Attachment]

    public init(body: Data, attachments: [Attachment] = [], schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.body = body
        self.attachments = attachments
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case body
        case attachments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        body = try container.decode(Data.self, forKey: .body)
        attachments = try container.decode([Attachment].self, forKey: .attachments)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if schemaVersion != 1 {
            try container.encode(schemaVersion, forKey: .schemaVersion)
        }
        try container.encode(body, forKey: .body)
        try container.encode(attachments, forKey: .attachments)
    }
}

extension NotePayload.Attachment: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case filename
        case mime
        case data
        case size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        mime = try container.decode(String.self, forKey: .mime)
        data = try container.decodeIfPresent(Data.self, forKey: .data)

        if let decodedSize = try container.decodeIfPresent(Int.self, forKey: .size) {
            size = decodedSize
        } else if let data {
            size = data.count
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .size,
                in: container,
                debugDescription: "Attachment requires either data or size."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(filename, forKey: .filename)
        try container.encode(mime, forKey: .mime)
        if let data {
            try container.encode(data, forKey: .data)
        } else {
            try container.encode(size, forKey: .size)
        }
    }
}

public struct MigratedNotePayload: Equatable, Sendable {
    public let payload: NotePayload
    public let attachmentBytes: [String: Data]

    public init(payload: NotePayload, attachmentBytes: [String: Data]) {
        self.payload = payload
        self.attachmentBytes = attachmentBytes
    }
}

/// Converts a decrypted v1 payload (inline attachment data) to a v2 index plus raw bytes keyed by new UUIDs.
public func migratePayloadV1ToV2(_ payload: NotePayload) throws -> MigratedNotePayload {
    var attachmentBytes: [String: Data] = [:]
    var index: [NotePayload.Attachment] = []

    for attachment in payload.attachments {
        guard let data = attachment.data else {
            throw SecureCryptoError.invalidInput(
                "Cannot migrate attachment '\(attachment.id)' without inline data."
            )
        }
        let newID = UUID().uuidString
        attachmentBytes[newID] = data
        index.append(
            NotePayload.Attachment(
                id: newID,
                filename: attachment.filename,
                mime: attachment.mime,
                size: data.count
            )
        )
    }

    return MigratedNotePayload(
        payload: NotePayload(body: payload.body, attachments: index, schemaVersion: 2),
        attachmentBytes: attachmentBytes
    )
}
