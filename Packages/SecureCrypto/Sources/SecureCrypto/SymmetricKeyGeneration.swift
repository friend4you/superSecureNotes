import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct CryptoKitKeyGenerator: SymmetricKeyGenerating {
    public init() {}

    public func generateSymmetricKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }
}

private let defaultKeyGenerator = CryptoKitKeyGenerator()

public func generateSymmetricKey() -> SymmetricKey {
    defaultKeyGenerator.generateSymmetricKey()
}
