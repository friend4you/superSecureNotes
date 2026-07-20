import CryptoKit

public protocol SymmetricKeyGenerating: Sendable {
    func generateSymmetricKey() -> SymmetricKey
}
