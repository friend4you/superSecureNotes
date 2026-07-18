import CryptoKit
import Foundation

public protocol KeyWrapping: Sendable {
    func wrapKey(_ key: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data
    func unwrapKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey
}
