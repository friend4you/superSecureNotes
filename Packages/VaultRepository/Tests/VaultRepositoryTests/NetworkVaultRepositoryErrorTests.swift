import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class NetworkVaultRepositoryErrorTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testTransportFailureMapsToNetworkError() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let repository = NetworkVaultRepository(
            baseURL: VaultFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            _ = try await repository.readHeader()
            XCTFail("Expected networkError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnhandledStatusMapsToServerError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        let repository = NetworkVaultRepository(
            baseURL: VaultFixtures.baseURL,
            tokenProvider: MockTokenProvider(),
            session: .stubbed()
        )

        do {
            _ = try await repository.readHeader()
            XCTFail("Expected serverError")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
