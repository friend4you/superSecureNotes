import XCTest

@testable import VaultRepository

final class URLProtocolStubSmokeTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testStubInterceptsRequests() async throws {
        let expectedURL = VaultFixtures.baseURL.appending(path: "vault/header")
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "GET")
            let response = TestHTTP.makeResponse(url: expectedURL, statusCode: 200)
            return (response, VaultFixtures.headerBytes)
        }

        let session = URLSession.stubbed()
        var request = URLRequest(url: expectedURL)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(data, VaultFixtures.headerBytes)
    }
}
