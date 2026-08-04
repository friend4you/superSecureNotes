import Foundation

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

    static func bodyData(from request: URLRequest) -> Data? {
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

private func requestBodyData(from request: URLRequest) -> Data? {
    TestHTTP.bodyData(from: request)
}

final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests.compactMap(\.url?.path)
    }

    func method(at index: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard requests.indices.contains(index) else { return nil }
        return requests[index].httpMethod
    }

    func path(at index: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard requests.indices.contains(index) else { return nil }
        return requests[index].url?.path
    }

    func bodyData(at index: Int) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard requests.indices.contains(index) else { return nil }
        return requestBodyData(from: requests[index])
    }

    func jsonObject(at index: Int) -> Any? {
        guard let bodyData = bodyData(at: index) else { return nil }
        return try? JSONSerialization.jsonObject(with: bodyData)
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

    var ifMatch: String? {
        lock.lock()
        defer { lock.unlock() }
        return request?.value(forHTTPHeaderField: "If-Match")
    }

    var bodyData: Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let request else { return nil }
        return requestBodyData(from: request)
    }
}
