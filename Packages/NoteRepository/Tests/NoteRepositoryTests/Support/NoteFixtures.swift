import Foundation
import NoteRepositoryProtocol
import SecureCrypto
import VaultRepositoryProtocol

enum NoteFixtures {
    static let baseURL = URL(string: "https://api.example.com/v1")!
    static let noteID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
    static let accessToken = "access-token"
    static let noteBytes: Data = {
        (try? NoteTestSupport.makeSampleWireNote(noteID: noteID, title: "My note")) ?? Data()
    }()

    static let sampleStoredNote = NoteTestSupport.makeSampleStoredNote(
        noteID: noteID,
        title: "My note",
        syncState: .synced
    )

    static let sampleSummary = NoteSummary(
        noteID: noteID,
        title: "My note",
        updatedAt: 1_700_000_000,
        syncState: .synced
    )

    static func listNotesJSON(summaries: [NoteSummary] = [sampleSummary]) -> Data {
        let entries = summaries.map { summary in
            """
            {
              "noteId": "\(summary.noteID.uuidString.lowercased())",
              "title": "\(summary.title)",
              "updatedAt": \(summary.updatedAt)
            }
            """
        }
        return Data("[\(entries.joined(separator: ","))]".utf8)
    }

    static func errorJSON(error: String, message: String) -> Data {
        Data(
            """
            {
              "error": "\(error)",
              "message": "\(message)"
            }
            """.utf8
        )
    }

    static func writeNoteResponseJSON(
        syncState: String = "synced",
        updatedAt: UInt64 = 1_700_000_100,
        etag: String = #"W/"abc123""#
    ) -> Data {
        let payload: [String: Any] = [
            "syncState": syncState,
            "updatedAt": updatedAt,
            "etag": etag,
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

struct MockTokenProvider: AccessTokenProviding {
    enum Failure: Error {
        case missingToken
    }

    let token: String?
    let error: Error?

    init(token: String? = NoteFixtures.accessToken, error: Error? = nil) {
        self.token = token
        self.error = error
    }

    func accessToken() async throws -> String {
        if let error {
            throw error
        }
        guard let token else {
            throw Failure.missingToken
        }
        return token
    }
}
