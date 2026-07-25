import AuthRepositoryProtocol
import XCTest

@testable import superSecureNotes

final class InMemoryAuthRepositoryTests: XCTestCase {
    func testRegisterStoresSession() async throws {
        let repository = InMemoryAuthRepository()

        let session = try await repository.register(
            RegisterCredentials(email: "user@example.com", password: "secret")
        )

        let currentSession = await repository.currentSession
        XCTAssertEqual(session, currentSession)
    }

    func testLoginStoresSessionAndUser() async throws {
        let repository = InMemoryAuthRepository()

        _ = try await repository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )

        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertNotNil(currentSession)
        XCTAssertEqual(currentUser?.email, "user@example.com")
    }

    func testLogoutClearsState() async throws {
        let repository = InMemoryAuthRepository()
        _ = try await repository.login(
            LoginCredentials(email: "user@example.com", password: "secret")
        )

        try await repository.logout()

        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertNil(currentSession)
        XCTAssertNil(currentUser)
    }

    func testRefreshSessionThrowsWhenNotAuthenticated() async {
        let repository = InMemoryAuthRepository()

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
