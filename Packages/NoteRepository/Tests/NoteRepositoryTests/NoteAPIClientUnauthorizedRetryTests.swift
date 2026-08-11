import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NoteAPIClientUnauthorizedRetryTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testListNotesRetriesAfterTokenRefresh() async throws {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            if request.url?.path.hasSuffix("/auth/refresh") == true {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, NoteFixtures.refreshJSON())
            }
            if requestCount == 1 {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
                return (response, NoteFixtures.errorJSON(error: "unauthorized", message: "Expired token."))
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON())
        }

        let client = NoteAPIClient(
            baseURL: NoteFixtures.baseURL,
            session: .stubbed(),
            refreshAccessToken: { "new-access-token" }
        )
        let notes = try await client.listNotes(accessToken: NoteFixtures.accessToken)

        XCTAssertEqual(notes, [NoteFixtures.sampleSummary])
        XCTAssertEqual(requestCount, 2)
    }

    func testListNotesMapsUnauthorizedAfterFailedRefresh() async {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, NoteFixtures.errorJSON(error: "unauthorized", message: "Expired token."))
        }

        let client = NoteAPIClient(
            baseURL: NoteFixtures.baseURL,
            session: .stubbed(),
            refreshAccessToken: {
                throw NoteRepositoryError.notAuthenticated
            }
        )

        do {
            _ = try await client.listNotes(accessToken: NoteFixtures.accessToken)
            XCTFail("Expected notAuthenticated")
        } catch let error as NoteRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(requestCount, 1)
    }
}

private extension NoteFixtures {
    static func refreshJSON() -> Data {
        Data(
            """
            {
              "accessToken": "new-access-token",
              "refreshToken": "new-refresh-token",
              "expiresIn": 3600
            }
            """.utf8
        )
    }
}
