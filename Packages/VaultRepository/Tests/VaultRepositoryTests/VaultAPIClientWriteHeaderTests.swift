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

        let client = VaultAPIClient(baseURL: VaultFixtures.baseURL, session: .stubbed())
        try await client.writeHeader(VaultFixtures.headerBytes, accessToken: VaultFixtures.accessToken)

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

        let client = VaultAPIClient(baseURL: VaultFixtures.baseURL, session: .stubbed())

        do {
            try await client.writeHeader(VaultFixtures.headerBytes, accessToken: VaultFixtures.accessToken)
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

        let client = VaultAPIClient(baseURL: VaultFixtures.baseURL, session: .stubbed())

        do {
            try await client.writeHeader(VaultFixtures.headerBytes, accessToken: VaultFixtures.accessToken)
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
