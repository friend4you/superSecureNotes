import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class NetworkVaultRepositoryFetchPublicKeyTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
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
