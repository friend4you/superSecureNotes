import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class NetworkVaultRepositoryReadHeaderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadHeaderReturnsBodyOnSuccess() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.headerBytes)
        }

        let repository = VaultTestSupport.makeRepository()

        let header = try await repository.readHeader()
        XCTAssertEqual(header, VaultFixtures.headerBytes)
    }

    func testReadHeaderMapsHeaderNotFound() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 404)
            return (response, VaultFixtures.errorJSON(error: "header_not_found", message: "No vault."))
        }

        let repository = VaultTestSupport.makeRepository()

        do {
            _ = try await repository.readHeader()
            XCTFail("Expected headerNotFound")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .headerNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
