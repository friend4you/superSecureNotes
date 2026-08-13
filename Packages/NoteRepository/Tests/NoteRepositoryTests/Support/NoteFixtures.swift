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

    static func pullListNotesJSON(
        noteID: UUID,
        title: String,
        updatedAt: UInt64,
        etag: String
    ) -> Data {
        let payload: [[String: Any]] = [[
            "noteId": noteID.uuidString.lowercased(),
            "title": title,
            "updatedAt": updatedAt,
            "syncState": "synced",
            "etag": etag,
        ]]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static let vaultHeaderBytes = Data([0x53, 0x53, 0x4E, 0x56, 0x02])

    static func listNotesJSON(
        summaries: [NoteSummary] = [sampleSummary],
        etags: [String?] = []
    ) -> Data {
        let entries = summaries.enumerated().map { index, summary in
            let etagField: String
            if index < etags.count, let etag = etags[index] {
                etagField = """
                ,
                      "etag": "\(etag)"
                """
            } else {
                etagField = ""
            }
            return """
            {
              "noteId": "\(summary.noteID.uuidString.lowercased())",
              "title": "\(summary.title)",
              "updatedAt": \(summary.updatedAt),
              "syncState": "\(summary.syncState.rawValue)"\(etagField)
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

    /// Handles catalog pull GETs from sync flush in tests.
    static func pullCatalogGETResponse(for request: URLRequest) -> (HTTPURLResponse, Data?)? {
        guard request.httpMethod == "GET", let path = request.url?.path else {
            return nil
        }
        let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
        if path == "/v1/notes" {
            return (response, listNotesJSON(summaries: []))
        }
        if path == "/v1/notes/shared" {
            return (response, listSharedNotesJSON(summaries: []))
        }
        return nil
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

    static func uploadInitResponseJSON(
        uploadId: UUID,
        chunkSize: Int,
        totalChunks: Int
    ) -> Data {
        let payload: [String: Any] = [
            "uploadId": uploadId.uuidString.lowercased(),
            "chunkSize": chunkSize,
            "totalChunks": totalChunks,
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static let uploadID = UUID(uuidString: "660E8400-E29B-41D4-A716-446655440001")!
    static let attachmentID = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440002")!
    static let ownerID = UUID(uuidString: "770E8400-E29B-41D4-A716-446655440000")!
    static let sharedAt = Date(timeIntervalSince1970: 1_700_000_500)
    static let recipientWrappedFEK = Data(repeating: 0xAB, count: 48)

    static func attachmentsManifestJSON(
        attachments: [(
            attachmentID: UUID,
            sizeBytes: UInt64,
            contentType: String?,
            etag: String?,
            totalChunks: Int,
            chunkSize: Int
        )] = []
    ) -> Data {
        let payload: [[String: Any]] = attachments.map { item in
            var entry: [String: Any] = [
                "attachmentId": item.attachmentID.uuidString.lowercased(),
                "sizeBytes": item.sizeBytes,
                "totalChunks": item.totalChunks,
                "chunkSize": item.chunkSize,
            ]
            if let contentType = item.contentType {
                entry["contentType"] = contentType
            } else {
                entry["contentType"] = NSNull()
            }
            if let etag = item.etag {
                entry["etag"] = etag
            } else {
                entry["etag"] = NSNull()
            }
            return entry
        }
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static func attachmentsManifestJSON(
        attachments: [(attachmentID: UUID, sizeBytes: UInt64, contentType: String?, etag: String?)]
    ) -> Data {
        attachmentsManifestJSON(
            attachments: attachments.map { item in
                (
                    attachmentID: item.attachmentID,
                    sizeBytes: item.sizeBytes,
                    contentType: item.contentType,
                    etag: item.etag,
                    totalChunks: 1,
                    chunkSize: max(Int(item.sizeBytes), 1)
                )
            }
        )
    }

    static func writeAttachmentResponseJSON(
        etag: String = #"W/"att-etag""#,
        noteEtag: String = #"W/"note-etag""#
    ) -> Data {
        let payload: [String: Any] = [
            "etag": etag,
            "noteEtag": noteEtag,
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// Responds to attachment chunked upload routes (init → chunks → complete). Returns `nil` if the path is unrelated.
    static func chunkedAttachmentUploadResponse(
        for request: URLRequest,
        uploadID: UUID = uploadID,
        chunkSize: Int = 5_242_880,
        etag: String = #"W/"att-etag""#,
        noteEtag: String = #"W/"note-etag""#
    ) -> (HTTPURLResponse, Data?)? {
        let path = request.url!.path
        guard path.contains("/attachments/"), path.contains("/uploads") else {
            return nil
        }

        if path.hasSuffix("/uploads"), request.httpMethod == "POST" {
            guard
                let bodyData = TestHTTP.bodyData(from: request),
                let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                let totalSize = body["totalSize"] as? Int
            else {
                return (TestHTTP.makeResponse(url: request.url!, statusCode: 400), Data())
            }
            let totalChunks = max(1, (totalSize + chunkSize - 1) / chunkSize)
            return (
                TestHTTP.makeResponse(url: request.url!, statusCode: 200),
                uploadInitResponseJSON(
                    uploadId: uploadID,
                    chunkSize: chunkSize,
                    totalChunks: totalChunks
                )
            )
        }

        if path.contains("/chunks/"), request.httpMethod == "PUT" {
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 204), nil)
        }

        if path.hasSuffix("/complete"), request.httpMethod == "POST" {
            return (
                TestHTTP.makeResponse(url: request.url!, statusCode: 200),
                writeAttachmentResponseJSON(etag: etag, noteEtag: noteEtag)
            )
        }

        return nil
    }

    static func isLegacyAttachmentBlobPath(_ path: String) -> Bool {
        guard path.contains("/attachments/") else {
            return false
        }
        if path.contains("/uploads") || path.contains("/chunks/") {
            return false
        }
        if path.hasSuffix("/attachments") {
            return false
        }
        return true
    }

    static func readSharedBodyJSON(
        noteID: UUID = noteID,
        wrappedFek: Data = recipientWrappedFEK,
        body: Data = noteBytes
    ) -> Data {
        let payload: [String: String] = [
            "noteId": noteID.uuidString.lowercased(),
            "wrappedFek": wrappedFek.base64EncodedString(),
            "body": body.base64EncodedString(),
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static let sampleSharedSummary = SharedNoteSummary(
        noteID: noteID,
        title: "My note",
        updatedAt: 1_700_000_000,
        etag: #"W/"shared-etag""#,
        ownerEmail: "owner@example.com",
        ownerID: ownerID,
        sharedAt: sharedAt
    )

    static func listSharedNotesJSON(
        summaries: [SharedNoteSummary] = [sampleSharedSummary]
    ) -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [[String: Any]] = summaries.map { summary in
            [
                "noteId": summary.noteID.uuidString.lowercased(),
                "title": summary.title,
                "updatedAt": summary.updatedAt,
                "etag": summary.etag,
                "ownerEmail": summary.ownerEmail,
                "ownerId": summary.ownerID.uuidString.lowercased(),
                "sharedAt": formatter.string(from: summary.sharedAt),
            ]
        }
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    static func readSharedNoteJSON(
        noteID: UUID = noteID,
        wrappedFek: Data = recipientWrappedFEK,
        blob: Data = noteBytes
    ) -> Data {
        let payload: [String: String] = [
            "noteId": noteID.uuidString.lowercased(),
            "wrappedFek": wrappedFek.base64EncodedString(),
            "blob": blob.base64EncodedString(),
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
