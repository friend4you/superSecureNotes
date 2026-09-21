import XCTest

@testable import AuthRepository
@testable import AuthRepositoryProtocol

final class NetworkAuthRepositoryDeleteAccountTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testDeleteAccountRequiresAuthentication() async {
        let repository = NetworkAuthRepository(
            baseURL: AuthFixtures.baseURL,
            session: .stubbed()
        )

        do {
            try await repository.deleteAccount(password: "secret-password")
            XCTFail("Expected not authenticated error")
        } catch {
            XCTAssertEqual(error as? AuthRepositoryError, .notAuthenticated)
        }
    }

    func testDeleteAccountRejectsEmptyPassword() async throws {
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

        do {
            try await repository.deleteAccount(password: "")
            XCTFail("Expected validation error")
        } catch {
            XCTAssertEqual(
                error as? AuthRepositoryError,
                .validationError("Password must not be empty.")
            )
        }
    }

    func testDeleteAccountSendsBearerTokenAndClearsStateOnSuccess() async throws {
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

        var capturedAuthorization: String?
        var capturedPath: String?
        var capturedPassword: String?
        URLProtocolStub.requestHandler = { request in
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            capturedPath = request.url?.path
            if let body = Self.requestBodyData(from: request),
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                capturedPassword = json["password"] as? String
            }
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        try await repository.deleteAccount(password: "secret-password")

        XCTAssertEqual(capturedAuthorization, "Bearer access-token")
        XCTAssertEqual(capturedPath, "/v1/auth/delete-account")
        XCTAssertEqual(capturedPassword, "secret-password")
        let currentSession = await repository.currentSession
        let currentUser = await repository.currentUser
        XCTAssertNil(currentSession)
        XCTAssertNil(currentUser)
    }

    func testDeleteAccountMapsInvalidCredentials() async throws {
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
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 401)
            return (response, AuthFixtures.errorJSON(error: "invalid_credentials", message: "Invalid password"))
        }

        do {
            try await repository.deleteAccount(password: "wrong-password")
            XCTFail("Expected invalid credentials error")
        } catch {
            XCTAssertEqual(error as? AuthRepositoryError, .invalidCredentials)
        }

        let currentSession = await repository.currentSession
        XCTAssertNotNil(currentSession)
    }

    private static func requestBodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody, !httpBody.isEmpty {
            return httpBody
        }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            }
        }

        return data.isEmpty ? nil : data
    }
}
