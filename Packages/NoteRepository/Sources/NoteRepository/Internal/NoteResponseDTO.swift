import Foundation

struct NoteSummaryResponseDTO: Decodable {
    let noteId: String
    let title: String
    let updatedAt: UInt64
    let syncState: String?
    let etag: String?
}

struct SharedNoteSummaryResponseDTO: Decodable {
    let noteId: String
    let title: String
    let updatedAt: UInt64
    let etag: String
    let ownerEmail: String
    let ownerId: String
    let sharedAt: Date
}

struct SharedNoteDownloadResponseDTO: Decodable {
    let noteId: String
    let wrappedFek: String
    let blob: String
}

struct ErrorResponseDTO: Decodable {
    let error: String
    let message: String
}

struct NoteWriteResponseDTO: Decodable {
    let syncState: String
    let updatedAt: UInt64
    let etag: String
}

struct NoteUploadInitResponseDTO: Decodable {
    let uploadId: String
    let chunkSize: Int
    let totalChunks: Int
}

struct AttachmentSummaryResponseDTO: Decodable {
    let attachmentId: String
    let sizeBytes: UInt64
    let contentType: String?
    let etag: String?
}

enum AttachmentManifestDefaults {
    static let contentType = "application/octet-stream"
}

struct AttachmentWriteResponseDTO: Decodable {
    let etag: String
    let noteEtag: String
}

struct SharedNoteBodyResponseDTO: Decodable {
    let noteId: String
    let wrappedFek: String
    let body: String
}

struct NoteUploadSession: Equatable, Sendable {
    let uploadID: UUID
    let chunkSize: Int
    let totalChunks: Int
}

struct RemoteAttachmentSummary: Equatable, Sendable {
    let attachmentID: UUID
    let sizeBytes: UInt64
    let contentType: String
    let etag: String?
}

struct AttachmentUploadResult: Equatable, Sendable {
    let etag: String?
    let noteEtag: String?
}

enum NoteJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }
}
