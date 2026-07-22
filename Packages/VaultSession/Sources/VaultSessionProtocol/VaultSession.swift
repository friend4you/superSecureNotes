import CryptoKit
import Foundation

public protocol VaultSession: Actor {
    var isActive: Bool { get }
    nonisolated var changes: AsyncStream<Bool> { get }

    func establish(_ keys: VaultSessionKeys)
    func clear()

    func udk() throws -> SymmetricKey
    func identityPrivateKey() throws -> Data
}
