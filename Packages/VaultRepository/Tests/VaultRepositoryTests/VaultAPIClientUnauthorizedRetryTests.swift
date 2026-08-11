import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class VaultAPIClientUnauthorizedRetryTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testReadHeaderRetriesAfterTokenRefresh() async throws {
        var requestCount = 0
        let tokenProvider = RefreshingMockTokenProvider()
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
                return (response, VaultFixtures.errorJSON(error: "unauthorized", message: "Expired token."))
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, VaultFixtures.headerBytes)
        }

        let client = VaultAPIClient(
            baseURL: VaultFixtures.baseURL,
            tokenProvider: tokenProvider,
            session: .stubbed()
        )
        let header = try await client.readHeader()

        XCTAssertEqual(header, VaultFixtures.headerBytes)
        XCTAssertEqual(requestCount, 2)
        let refreshCallCount = await tokenProvider.refreshCallCount
        XCTAssertEqual(refreshCallCount, 1)
    }

    func testReadHeaderMapsUnauthorizedAfterFailedRefresh() async {
        let tokenProvider = RefreshingMockTokenProvider(refreshError: VaultRepositoryError.notAuthenticated)
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, VaultFixtures.errorJSON(error: "unauthorized", message: "Expired token."))
        }

        let client = VaultAPIClient(
            baseURL: VaultFixtures.baseURL,
            tokenProvider: tokenProvider,
            session: .stubbed()
        )

        do {
            _ = try await client.readHeader()
            XCTFail("Expected notAuthenticated")
        } catch let error as VaultRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor RefreshingMockTokenProvider: AccessTokenRefreshing {
    private(set) var refreshCallCount = 0
    private let refreshError: Error?

    init(refreshError: Error? = nil) {
        self.refreshError = refreshError
    }

    func accessToken() async throws -> String {
        VaultFixtures.accessToken
    }

    func refreshAccessToken() async throws -> String {
        refreshCallCount += 1
        if let refreshError {
            throw refreshError
        }
        return "new-access-token"
    }
}
