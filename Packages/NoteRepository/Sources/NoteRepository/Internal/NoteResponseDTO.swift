import Foundation

struct NoteSummaryResponseDTO: Decodable {
    let noteId: String
    let title: String
    let updatedAt: UInt64
    let syncState: String?
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

enum NoteJSON {
    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
