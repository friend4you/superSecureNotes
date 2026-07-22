import Foundation

public protocol AccessTokenProviding: Sendable {
    func accessToken() async throws -> String
}
