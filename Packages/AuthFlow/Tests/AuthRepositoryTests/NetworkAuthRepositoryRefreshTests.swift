import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryRefreshTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testRefreshUpdatesTokensOnSuccess() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if request.url?.path.hasSuffix("/auth/login") == true {
                return (response, AuthFixtures.authSuccessJSON())
            }
            return (response, AuthFixtures.refreshJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        let refreshed = try await repository.refreshSession()

        XCTAssertEqual(refreshed.accessToken, "new-access-token")
        XCTAssertEqual(refreshed.refreshToken, "new-refresh-token")
        let currentSession = await repository.currentSession
        XCTAssertEqual(currentSession, refreshed)
    }

    func testRefreshThrowsWhenNotAuthenticated() async {
        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.refreshSession()
            XCTFail("Expected notAuthenticated")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRefreshMapsUnauthorizedFromServer() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            if request.url?.path.hasSuffix("/auth/login") == true {
                return (response, AuthFixtures.authSuccessJSON())
            }
            return (
                TestHTTP.makeResponse(url: request.url!, statusCode: 401),
                AuthFixtures.errorJSON(error: "unauthorized", message: "Expired refresh token.")
            )
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        _ = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        do {
            _ = try await repository.refreshSession()
            XCTFail("Expected notAuthenticated")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
