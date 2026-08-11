import Foundation

public enum AuthorizedHTTPPerform {
    public static func isUnauthorized(statusCode: Int, data: Data) -> Bool {
        guard statusCode == 401,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? String
        else {
            return false
        }
        return error == "unauthorized"
    }

    public static func data(
        for request: URLRequest,
        session: URLSession,
        expectedSuccessCodes: Set<Int>,
        refreshAccessToken: (@Sendable () async throws -> String)?,
        mapTransportError: () -> Error,
        mapHTTPError: (Int, Data) -> Error
    ) async throws -> Data {
        var request = request
        for attempt in 0..<2 {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw mapTransportError()
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw mapTransportError()
            }

            let statusCode = httpResponse.statusCode
            if expectedSuccessCodes.contains(statusCode) {
                return data
            }

            if attempt == 0,
               let refreshAccessToken,
               isUnauthorized(statusCode: statusCode, data: data) {
                let newToken = try await refreshAccessToken()
                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                continue
            }

            throw mapHTTPError(statusCode, data)
        }

        throw mapHTTPError(401, Data())
    }
}
