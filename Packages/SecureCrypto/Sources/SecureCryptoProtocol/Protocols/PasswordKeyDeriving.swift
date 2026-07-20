import CryptoKit
import Foundation

public protocol PasswordKeyDeriving: Sendable {
    var algorithmID: UInt8 { get }
    var iterations: Int { get }

    func deriveKey(password: String, salt: Data) throws -> SymmetricKey
    func serializeParameters(salt: Data) throws -> Data
}
