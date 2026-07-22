import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryRegisterTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testRegisterParsesResponseAndStoresState() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 201)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        let session = try await repository.register(
            RegisterCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        XCTAssertEqual(session.accessToken, "access-token")
        XCTAssertEqual(session.refreshToken, "refresh-token")
        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertEqual(currentSession, session)
        XCTAssertEqual(currentUser?.id, AuthFixtures.userID)
        XCTAssertEqual(currentUser?.email, AuthFixtures.email)
    }

    func testRegisterMapsEmailAlreadyExists() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 409)
            return (response, AuthFixtures.errorJSON(error: "email_already_exists", message: "Email taken."))
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.register(
                RegisterCredentials(email: AuthFixtures.email, password: "secret-password")
            )
            XCTFail("Expected emailAlreadyExists")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .emailAlreadyExists)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRegisterMapsValidationError() async {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 400)
            return (response, AuthFixtures.errorJSON(error: "validation_error", message: "Password too short."))
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.register(
                RegisterCredentials(email: AuthFixtures.email, password: "secret-password")
            )
            XCTFail("Expected validationError")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .validationError("Password too short."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRegisterRejectsEmptyCredentialsLocally() async {
        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.register(RegisterCredentials(email: "", password: "secret"))
            XCTFail("Expected validationError")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .validationError("Email and password must not be empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
