import Foundation

enum AuthFixtures {
    static let baseURL = URL(string: "https://api.example.com/v1")!

    static let userID = "550e8400-e29b-41d4-a716-446655440000"
    static let email = "user@example.com"
    static let createdAt = "2026-07-22T12:00:00Z"

    static func authSuccessJSON(
        accessToken: String = "access-token",
        refreshToken: String = "refresh-token",
        expiresIn: Int = 3600
    ) -> Data {
        Data(
            """
            {
              "user": {
                "id": "\(userID)",
                "email": "\(email)",
                "createdAt": "\(createdAt)"
              },
              "accessToken": "\(accessToken)",
              "refreshToken": "\(refreshToken)",
              "expiresIn": \(expiresIn)
            }
            """.utf8
        )
    }

    static func refreshJSON(
        accessToken: String = "new-access-token",
        refreshToken: String = "new-refresh-token",
        expiresIn: Int = 3600
    ) -> Data {
        Data(
            """
            {
              "accessToken": "\(accessToken)",
              "refreshToken": "\(refreshToken)",
              "expiresIn": \(expiresIn)
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
