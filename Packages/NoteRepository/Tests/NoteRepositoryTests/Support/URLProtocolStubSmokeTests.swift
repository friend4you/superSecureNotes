import XCTest

@testable import NoteRepository

final class URLProtocolStubSmokeTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testStubInterceptsRequests() async throws {
        let expectedURL = NoteFixtures.baseURL.appending(path: "notes")
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "GET")
            let response = TestHTTP.makeResponse(url: expectedURL, statusCode: 200)
            return (response, NoteFixtures.listNotesJSON())
        }

        let session = URLSession.stubbed()
        var request = URLRequest(url: expectedURL)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(data, NoteFixtures.listNotesJSON())
    }
}
