import Foundation

struct NoteSummaryResponseDTO: Decodable {
    let noteId: String
    let title: String
    let updatedAt: UInt64
    let syncState: String?
    let etag: String?
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

struct NoteUploadSession: Equatable, Sendable {
    let uploadID: UUID
    let chunkSize: Int
    let totalChunks: Int
}

enum NoteJSON {
    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
