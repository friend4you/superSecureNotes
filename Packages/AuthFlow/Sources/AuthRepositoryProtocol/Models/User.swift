import Foundation

public struct User: Sendable, Equatable, Codable {
    public let id: String
    public let email: String
    public let createdAt: Date

    public init(id: String, email: String, createdAt: Date) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
    }
}
