import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class VaultAPIClientWriteHeaderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteHeaderSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = VaultTestSupport.makeAPIClient()
        try await client.writeHeader(VaultFixtures.headerBytes)

        XCTAssertEqual(captured.method, "PUT")
        XCTAssertEqual(captured.path, "/v1/vault/header")
        XCTAssertEqual(captured.authorization, "Bearer \(VaultFixtures.accessToken)")
        XCTAssertEqual(captured.contentType, "application/octet-stream")
        XCTAssertEqual(captured.bodyData, VaultFixtures.headerBytes)
    }

    func testWriteHeaderMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, VaultFixtures.errorJSON(error: "validation_error", message: "Invalid header."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            try await client.writeHeader(VaultFixtures.headerBytes)
            XCTFail("Expected validationError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .validationError("Invalid header."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteHeaderMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, VaultFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            try await client.writeHeader(VaultFixtures.headerBytes)
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteHeaderPropagatesTokenProviderFailure() async {
        let client = VaultTestSupport.makeAPIClient(
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken)
        )

        do {
            try await client.writeHeader(VaultFixtures.headerBytes)
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
