import Foundation

public protocol VaultRepository: Sendable {
    func readHeader() async throws -> Data
    func writeHeader(_ header: Data) async throws
    func fetchPublicKey(userID: String) async throws -> Data
    func fetchPublicKey(email: String) async throws -> Data
}
