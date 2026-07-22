import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryErrorTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testTransportFailureMapsToNetworkError() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.login(
                LoginCredentials(email: AuthFixtures.email, password: "secret-password")
            )
            XCTFail("Expected networkError")
        } catch let error as AuthRepositoryError {
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

        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            _ = try await repository.login(
                LoginCredentials(email: AuthFixtures.email, password: "secret-password")
            )
            XCTFail("Expected serverError")
        } catch let error as AuthRepositoryError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNewRepositoryInstanceHasNoPriorSession() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 200)
            return (response, AuthFixtures.authSuccessJSON())
        }

        let firstRepository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )
        _ = try await firstRepository.login(
            LoginCredentials(email: AuthFixtures.email, password: "secret-password")
        )

        let secondRepository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        let currentSession = await secondRepository.currentSession
        let currentUser = await secondRepository.currentUser
        XCTAssertNil(currentSession)
        XCTAssertNil(currentUser)
    }
}
