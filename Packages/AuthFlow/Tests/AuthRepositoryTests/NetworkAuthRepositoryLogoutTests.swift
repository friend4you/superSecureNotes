import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryLogoutTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testLogoutSendsBearerTokenAndClearsStateOnSuccess() async throws {
        var capturedAuthorization: String?
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        URLProtocolStub.requestHandler = { request in
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        try await repository.logout()

        XCTAssertEqual(capturedAuthorization, "Bearer access-token")
        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertNil(currentSession)
        XCTAssertNil(currentUser)
    }

    func testLogoutClearsStateOnNetworkFailure() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        try await repository.logout()

        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertNil(currentSession)
        XCTAssertNil(currentUser)
    }
}
