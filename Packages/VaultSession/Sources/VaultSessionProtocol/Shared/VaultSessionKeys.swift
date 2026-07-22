import CryptoKit
import Foundation

public struct VaultSessionKeys: Sendable {
    public let udk: SymmetricKey
    public let identityPrivateKey: Data

    public init(udk: SymmetricKey, identityPrivateKey: Data) {
        self.udk = udk
        self.identityPrivateKey = identityPrivateKey
    }
}

extension VaultSessionKeys: Equatable {
    public static func == (lhs: VaultSessionKeys, rhs: VaultSessionKeys) -> Bool {
        lhs.identityPrivateKey == rhs.identityPrivateKey
            && symmetricKeyBytes(lhs.udk) == symmetricKeyBytes(rhs.udk)
    }
}

private func symmetricKeyBytes(_ key: SymmetricKey) -> Data {
    key.withUnsafeBytes { Data($0) }
}
