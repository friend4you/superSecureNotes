import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class NetworkVaultRepositoryWriteHeaderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testWriteHeaderSucceedsOnNoContent() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let repository = VaultTestSupport.makeRepository()

        try await repository.writeHeader(VaultFixtures.headerBytes)
    }

    func testWriteHeaderRejectsEmptyDataLocally() async {
        let repository = VaultTestSupport.makeRepository()

        do {
            try await repository.writeHeader(Data())
            XCTFail("Expected validationError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .validationError("Vault header must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteHeaderMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, VaultFixtures.errorJSON(error: "validation_error", message: "Invalid header."))
        }

        let repository = VaultTestSupport.makeRepository()

        do {
            try await repository.writeHeader(VaultFixtures.headerBytes)
            XCTFail("Expected validationError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .validationError("Invalid header."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
