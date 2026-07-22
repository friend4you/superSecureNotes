import Foundation
import SecureCrypto
import VaultSessionProtocol

public struct SecureCryptoVaultAuthenticator: VaultAuthenticator {
    public init() {}

    public func createVault(password: String) throws -> VaultCreationOutcome {
        let result = try SecureCrypto.createVault(password: password)
        let headerData = try result.header.serialized()
        return VaultCreationOutcome(headerData: headerData, mnemonic: result.mnemonic)
    }

    public func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome {
        let header = try VaultHeader.parse(headerData)
        let unlockResult = try SecureCrypto.unlockVault(header: header, password: password)
        let identityPrivateKey = try unwrapIdentityPrivateKey(
            header: unlockResult.header,
            udk: unlockResult.udk
        )
        let sessionKeys = VaultSessionKeys(
            udk: unlockResult.udk,
            identityPrivateKey: identityPrivateKey
        )
        return VaultUnlockOutcome(sessionKeys: sessionKeys)
    }
}
