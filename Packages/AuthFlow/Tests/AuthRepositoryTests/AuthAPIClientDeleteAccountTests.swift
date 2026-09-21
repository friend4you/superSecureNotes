import XCTest

@testable import AuthRepository

final class AuthAPIClientDeleteAccountTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testDeleteAccountSendsExpectedRequest() async throws {
        let captured = RequestCapture()
        URLProtocolStub.requestHandler = { request in
            captured.record(request)
            let response = TestHTTP.makeResponse(url: request.url!, statusCode: 204)
            return (response, nil)
        }

        let client = AuthAPIClient(baseURL: AuthFixtures.baseURL, session: .stubbed())
        try await client.deleteAccount(accessToken: "access-token", password: "secret-password")

        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(captured.path, "/v1/auth/delete-account")
        XCTAssertEqual(captured.authorization, "Bearer access-token")
        XCTAssertEqual(captured.contentType, "application/json")
        XCTAssertEqual(captured.jsonBody?["password"] as? String, "secret-password")
    }
}

private final class RequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    func record(_ request: URLRequest) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    var method: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.httpMethod
    }

    var path: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.url?.path
    }

    var contentType: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.value(forHTTPHeaderField: "Content-Type")
    }

    var authorization: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.value(forHTTPHeaderField: "Authorization")
    }

    var jsonBody: [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = bodyData(from: request) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func bodyData(from request: URLRequest?) -> Data? {
        guard let request else { return nil }
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
