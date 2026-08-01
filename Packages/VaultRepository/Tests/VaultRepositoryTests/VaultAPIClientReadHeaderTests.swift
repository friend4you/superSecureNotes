import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class VaultAPIClientReadHeaderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadHeaderSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.headerBytes)
        }

        let client = VaultTestSupport.makeAPIClient()
        let header = try await client.readHeader()

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/vault/header")
        XCTAssertEqual(captured.authorization, "Bearer \(VaultFixtures.accessToken)")
        XCTAssertEqual(header, VaultFixtures.headerBytes)
    }

    func testReadHeaderMapsHeaderNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, VaultFixtures.errorJSON(error: "header_not_found", message: "No vault."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.readHeader()
            XCTFail("Expected headerNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .headerNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadHeaderMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, VaultFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.readHeader()
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReadHeaderPropagatesTokenProviderFailure() async {
        let client = VaultTestSupport.makeAPIClient(
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken)
        )

        do {
            _ = try await client.readHeader()
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
