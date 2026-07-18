import CryptoKit
import Foundation

public protocol SymmetricCipher: Sendable {
    func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data
    func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data
}
