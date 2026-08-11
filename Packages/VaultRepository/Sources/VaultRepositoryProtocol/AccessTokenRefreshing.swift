import Foundation

public protocol AccessTokenRefreshing: AccessTokenProviding {
    func refreshAccessToken() async throws -> String
}
