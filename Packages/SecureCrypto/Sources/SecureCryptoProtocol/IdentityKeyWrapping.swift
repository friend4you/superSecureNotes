import CryptoKit
import Foundation

public protocol IdentityKeyWrapping: Sendable {
    func wrapPrivateKey(_ privateKey: Data, with wrappingKey: SymmetricKey) throws -> Data
    func unwrapPrivateKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> Data
}
