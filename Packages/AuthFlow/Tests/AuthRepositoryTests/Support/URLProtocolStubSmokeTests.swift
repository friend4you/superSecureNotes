import XCTest

@testable import AuthRepository

final class URLProtocolStubSmokeTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testStubInterceptsRequests() async throws {
        let expectedURL = AuthFixtures.baseURL.appending(path: "auth/login")
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "POST")
            let response = TestHTTP.makeResponse(url: expectedURL, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let session = URLSession.stubbed()
        var request = URLRequest(url: expectedURL)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertFalse(data.isEmpty)
    }
}
