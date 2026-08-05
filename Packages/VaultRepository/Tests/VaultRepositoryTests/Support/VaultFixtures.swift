import Foundation
import VaultRepositoryProtocol

enum VaultFixtures {
    static let baseURL = URL(string: "https://api.example.com/v1")!
    static let userID = "550e8400-e29b-41d4-a716-446655440000"
    static let email = "user@example.com"
    static let accessToken = "access-token"
    static let headerBytes = Data([0x53, 0x53, 0x4E, 0x56, 0x02])

    static func publicKeyJSON(publicKey: Data = Data(repeating: 0x11, count: 32), algorithmId: Int = 1) -> Data {
        Data(
            """
            {
              "publicKey": "\(publicKey.base64EncodedString())",
              "algorithmId": \(algorithmId)
            }
            """.utf8
        )
    }

    static func errorJSON(error: String, message: String) -> Data {
        Data(
            """
            {
              "error": "\(error)",
              "message": "\(message)"
            }
            """.utf8
        )
    }
}

final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    static func stubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

enum TestHTTP {
    static func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}

final class RequestCapture: @unchecked Sendable {
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

    var query: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.url?.query
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

    var bodyData: Data? {
        lock.lock()
        defer { lock.unlock() }
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

struct MockTokenProvider: AccessTokenProviding {
    enum Failure: Error {
        case missingToken
    }

    let token: String?
    let error: Error?

    init(token: String? = VaultFixtures.accessToken, error: Error? = nil) {
        self.token = token
        self.error = error
    }

    func accessToken() async throws -> String {
        if let error {
            throw error
        }
        guard let token else {
            throw Failure.missingToken
        }
        return token
    }
}
