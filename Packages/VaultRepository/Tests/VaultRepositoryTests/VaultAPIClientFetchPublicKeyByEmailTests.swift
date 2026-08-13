import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class VaultAPIClientFetchPublicKeyByEmailTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testFetchPublicKeyByEmailSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        let expectedKey = Data(repeating: 0x33, count: 32)
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.publicKeyJSON(publicKey: expectedKey))
        }

        let client = VaultTestSupport.makeAPIClient()
        let publicKey = try await client.fetchPublicKey(email: VaultFixtures.email)

        XCTAssertEqual(captured.method, "GET")
        XCTAssertEqual(captured.path, "/v1/users/public-key")
        XCTAssertEqual(captured.query, "email=\(VaultFixtures.email)")
        XCTAssertEqual(captured.authorization, "Bearer \(VaultFixtures.accessToken)")
        XCTAssertEqual(publicKey, expectedKey)
        XCTAssertEqual(publicKey.count, 32)
    }

    func testFetchPublicKeyByEmailMapsPublicKeyNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, VaultFixtures.errorJSON(error: "public_key_not_found", message: "No key."))
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.fetchPublicKey(email: VaultFixtures.email)
            XCTFail("Expected publicKeyNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .publicKeyNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPublicKeyByEmailMapsUserNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (
                response,
                VaultFixtures.errorJSON(error: "user_not_found", message: "Recipient user not found.")
            )
        }

        let client = VaultTestSupport.makeAPIClient()

        do {
            _ = try await client.fetchPublicKey(email: VaultFixtures.email)
            XCTFail("Expected userNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .userNotFound("Recipient user not found."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPublicKeyByEmailRejectsEmptyEmailLocally() async {
        let repository = VaultTestSupport.makeRepository()
        var didSendNetworkRequest = false
        URLProtocolStub.requestHandler = { request in
            didSendNetworkRequest = true
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.publicKeyJSON())
        }

        do {
            _ = try await repository.fetchPublicKey(email: "")
            XCTFail("Expected validationError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .validationError("Email must not be empty."))
            XCTAssertFalse(didSendNetworkRequest)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
