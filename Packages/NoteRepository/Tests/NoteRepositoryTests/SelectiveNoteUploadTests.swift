import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol
import SecureCrypto

final class SelectiveNoteUploadTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testBodyOnlyUploadSkipsAttachmentRoutes() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let attachmentID = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440010")!
        let ciphertext = Data(repeating: 0x11, count: 32)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Updated title",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_200,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xEE, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == bodyPath {
                return (response, NoteFixtures.writeNoteResponseJSON(etag: #"W/"body-only""#))
            }
            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments",
               request.httpMethod == "GET"
            {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(
                        attachments: [(
                            attachmentID: attachmentID,
                            sizeBytes: UInt64(ciphertext.count),
                            contentType: "application/octet-stream",
                            etag: #"W/"att-etag""#,
                            totalChunks: 1,
                            chunkSize: 5_242_880
                        )]
                    )
                )
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let result = try await repository.uploadNote(
            note,
            ifMatch: #"W/"composite""#,
            attachmentIDsToUpload: [],
            uploadBody: true,
            uploadSessionStore: nil,
            attachmentReplacementEtags: [:]
        )

        XCTAssertEqual(result.etag, #"W/"body-only""#)
        XCTAssertEqual(log.paths, [
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments",
            bodyPath,
        ])
    }

    func testUploadOnlyPendingAttachmentSkipsBodyPut() async throws {
        let log = RequestLog()
        let noteID = NoteFixtures.noteID
        let existingAttachmentID = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440010")!
        let newAttachmentID = UUID(uuidString: "880E8400-E29B-41D4-A716-446655440011")!
        let existingCiphertext = Data(repeating: 0x11, count: 32)
        let newCiphertext = Data(repeating: 0x22, count: 48)
        let bodyPath = "/v1/notes/\(noteID.uuidString.lowercased())/body"
        let newAttachmentBase =
            "/v1/notes/\(noteID.uuidString.lowercased())/attachments/\(newAttachmentID.uuidString.lowercased())"

        let note = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Same title",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 2,
                attachmentsTotalSize: UInt64(existingCiphertext.count + newCiphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .pendingSync,
            attachmentCiphertexts: [
                existingAttachmentID: existingCiphertext,
                newAttachmentID: newCiphertext,
            ]
        )

        URLProtocolStub.requestHandler = { request in
            log.record(request)
            let path = request.url!.path
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)

            if path == "/v1/notes/\(noteID.uuidString.lowercased())/attachments",
               request.httpMethod == "GET"
            {
                return (
                    response,
                    NoteFixtures.attachmentsManifestJSON(
                        attachments: [(
                            attachmentID: existingAttachmentID,
                            sizeBytes: UInt64(existingCiphertext.count),
                            contentType: "application/octet-stream",
                            etag: #"W/"att-1""#,
                            totalChunks: 1,
                            chunkSize: 5_242_880
                        )]
                    )
                )
            }

            if let chunked = NoteFixtures.chunkedAttachmentUploadResponse(
                for: request,
                noteEtag: #"W/"note-etag""#
            ) {
                return chunked
            }

            XCTFail("Unexpected path: \(path)")
            return (TestHTTP.makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let repository = NetworkNoteRepository(
            baseURL: NoteFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        let result = try await repository.uploadNote(
            note,
            ifMatch: #"W/"composite""#,
            attachmentIDsToUpload: [newAttachmentID],
            uploadBody: false,
            uploadSessionStore: nil,
            attachmentReplacementEtags: [:]
        )

        XCTAssertEqual(result.etag, #"W/"note-etag""#)
        XCTAssertFalse(log.paths.contains(bodyPath))
        XCTAssertTrue(log.paths.contains("\(newAttachmentBase)/uploads"))
        XCTAssertFalse(
            log.paths.contains {
                $0.contains(existingAttachmentID.uuidString.lowercased()) && $0.contains("/uploads")
            }
        )
    }

    func testWriteNotePreservesSyncedAttachmentStateWhenCiphertextUnchanged() async throws {
        let notesRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let (indexStore, repository) = NoteTestSupport.makeLocalRepository(notesRootURL: notesRootURL)
        let noteID = NoteFixtures.noteID
        let attachmentID = NoteFixtures.attachmentID
        let ciphertext = Data(repeating: 0x55, count: 64)

        try await NoteTestSupport.openIndexStore(indexStore)
        let initialNote = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Title",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_100,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: Data(repeating: 0xAB, count: 60),
            encryptedPayload: Data(repeating: 0xCD, count: 128),
            syncState: .synced,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )
        try await repository.writeNote(initialNote)
        try await indexStore.upsertAttachment(
            AttachmentIndexRow(
                noteID: noteID,
                attachmentID: attachmentID,
                etag: #"W/"att""#,
                sizeBytes: UInt64(ciphertext.count),
                syncState: .synced
            )
        )
        try await indexStore.upsertNote(
            NoteIndexRow(
                noteID: noteID,
                title: initialNote.metadata.title,
                createdAt: initialNote.metadata.createdAt,
                updatedAt: initialNote.metadata.updatedAt,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count),
                wrappedFEK: initialNote.wrappedFEK,
                syncState: .pendingSync,
                bodyEtag: nil,
                etag: #"W/"etag""#
            )
        )

        let updatedPayload = Data(repeating: 0xEE, count: 128)
        let updatedNote = StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "Updated title",
                createdAt: 1_700_000_000,
                updatedAt: 1_700_000_200,
                attachmentCount: 1,
                attachmentsTotalSize: UInt64(ciphertext.count)
            ),
            wrappedFEK: initialNote.wrappedFEK,
            encryptedPayload: updatedPayload,
            syncState: .pendingSync,
            attachmentCiphertexts: [attachmentID: ciphertext]
        )
        try await repository.writeNote(updatedNote)

        let attachmentRow = try await indexStore.fetchAttachment(
            noteID: noteID,
            attachmentID: attachmentID
        )
        XCTAssertEqual(attachmentRow?.syncState, .synced)
        XCTAssertEqual(attachmentRow?.etag, #"W/"att""#)

        let candidates = try await repository.uploadCandidates()
        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].uploadBody)
        XCTAssertTrue(candidates[0].attachmentIDsToUpload.isEmpty)
    }
}
