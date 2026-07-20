import CryptoKit
import Foundation

public protocol RecoveryKeyDeriving: Sendable {
    func deriveKey(entropy: Data) throws -> SymmetricKey
}
