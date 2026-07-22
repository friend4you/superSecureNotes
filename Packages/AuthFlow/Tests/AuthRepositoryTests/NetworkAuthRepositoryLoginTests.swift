import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryLoginTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testLoginParsesResponseAndStoresState() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        let session = try await repository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        XCTAssertEqual(session.accessToken, "access-token")
        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertEqual(currentSession, session)
        XCTAssertEqual(currentUser?.email, AuthFixtures.email)
    }

    func testLoginMapsInvalidCredentials() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, AuthFixtures.errorJSON(error: "invalid_credentials", message: "Wrong password."))
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.login(
                LoginCredentials(email: AuthFixtures.email, password: "wrong-password")
            )
            XCTFail("Expected invalidCredentials")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoginRejectsEmptyCredentialsLocally() async {
        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.login(LoginCredentials(email: AuthFixtures.email, password: ""))
            XCTFail("Expected validationError")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .validationError("Email and password must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
