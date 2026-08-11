import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryRefreshCoalescingTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testParallelRefreshCallersShareOneNetworkCall() async throws {
        var refreshCallCount = 0
        URLProtocolStub.requestHandler = { request in
            if request.url?.path.hasSuffix("/auth/login") == true {
                let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
                return (response, AuthFixtures.authSuccessJSON())
            }
            refreshCallCount += 1
            Thread.sleep(forTimeInterval: 0.05)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.refreshJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )
        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        async let first = repository.refreshSession()
        async let second = repository.refreshSession()
        let sessions = try await [first, second]

        XCTAssertEqual(refreshCallCount, 1)
        XCTAssertEqual(sessions[0], sessions[1])
        XCTAssertEqual(sessions[0].accessToken, "new-access-token")
    }
}
