import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class VaultAPIClientFetchPublicKeyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testFetchPublicKeySendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let expectedKey = Data(repeating: 0x11, count: 32)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.publicKeyJSON(publicKey: expectedKey))
        }

        let client = VaultTestSupport.makeAPIClient()
        let publicKey = try await client.fetchPublicKey(userID: VaultFixtures.userID)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/users/\(VaultFixtures.userID)/public-key")
        XCTAssertEqual(captured.authorization, "Bearer \(VaultFixtures.accessToken)")
        XCTAssertEqual(publicKey, expectedKey)
        XCTAssertEqual(publicKey.count, 32)
    }

    func testFetchPublicKeyMapsPublicKeyNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, VaultFixtures.errorJSON(error: "public_key_not_found", message: "No key."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.fetchPublicKey(userID: VaultFixtures.userID)
            XCTFail("Expected publicKeyNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .publicKeyNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPublicKeyMapsUnauthorized() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, VaultFixtures.errorJSON(error: "unauthorized", message: "Invalid token."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.fetchPublicKey(userID: VaultFixtures.userID)
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPublicKeyPropagatesTokenProviderFailure() async {
        let client = VaultTestSupport.makeAPIClient(
            tokenProvider: MockTokenProvider(error: MockTokenProvider.Failure.missingToken)
        )

        do {
            _ = try await client.fetchPublicKey(userID: VaultFixtures.userID)
            XCTFail("Expected token provider error")
        } catch is MockTokenProvider.Failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
