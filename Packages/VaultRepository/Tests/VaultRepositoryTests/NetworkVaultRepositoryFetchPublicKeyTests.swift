import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class NetworkVaultRepositoryFetchPublicKeyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testFetchPublicKeyReturnsThirtyTwoBytesOnSuccess() async throws {
        let expectedKey = Data(repeating: 0x22, count: 32)
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.publicKeyJSON(publicKey: expectedKey))
        }

        let repository = VaultTestSupport.makeRepository()

        let publicKey = try await repository.fetchPublicKey(userID: VaultFixtures.userID)
        XCTAssertEqual(publicKey, expectedKey)
        XCTAssertEqual(publicKey.count, 32)
    }

    func testFetchPublicKeyMapsPublicKeyNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, VaultFixtures.errorJSON(error: "public_key_not_found", message: "No key."))
        }

        let repository = VaultTestSupport.makeRepository()

        do {
            _ = try await repository.fetchPublicKey(userID: VaultFixtures.userID)
            XCTFail("Expected publicKeyNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .publicKeyNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPublicKeyRejectsEmptyUserIDLocally() async {
        let repository = VaultTestSupport.makeRepository()

        do {
            _ = try await repository.fetchPublicKey(userID: "")
            XCTFail("Expected validationError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .validationError("User ID must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
