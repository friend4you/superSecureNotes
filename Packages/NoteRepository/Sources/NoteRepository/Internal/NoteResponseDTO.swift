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

enum NoteJSON {
    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
