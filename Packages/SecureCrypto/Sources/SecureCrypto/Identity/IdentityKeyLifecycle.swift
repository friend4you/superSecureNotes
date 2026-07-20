import CryptoKit
import Foundation
import SecureCryptoProtocol

public func unwrapIdentityPrivateKey(header: VaultHeader, udk: SymmetricKey) throws -> Data {
    guard header.hasIdentity,
          let wrappedPrivateKey = header.wrappedIdentityPrivateKey,
          let storedPublicKey = header.identityPublicKey else {
        throw SecureCryptoError.invalidInput("Vault header does not contain identity fields.")
    }

    let privateKey = try unwrapIdentityPrivateKey(wrappedPrivateKey, with: udk)
    let derivedPublicKey = try Curve25519.KeyAgreement.PrivateKey(
        rawRepresentation: privateKey
    ).publicKey.rawRepresentation

    guard derivedPublicKey == storedPublicKey else {
        throw SecureCryptoError.authenticationFailed
    }

    return privateKey
}

func upgradeHeaderWithIdentity(_ header: VaultHeader, udk: SymmetricKey) throws -> VaultHeader {
    if header.hasIdentity {
        return header
    }

    let keyPair = generateIdentityKeyPair()
    let wrappedPrivateKey = try wrapIdentityPrivateKey(keyPair.privateKey, with: udk)

    return VaultHeader(
        kdfID: header.kdfID,
        salt: header.salt,
        iterations: header.iterations,
        wrappedUDKPassword: header.wrappedUDKPassword,
        wrappedUDKRecovery: header.wrappedUDKRecovery,
        identityAlgorithmID: Curve25519KeyPairGenerator.algorithmID,
        identityPublicKey: keyPair.publicKey,
        wrappedIdentityPrivateKey: wrappedPrivateKey
    )
}

func makeVaultHeaderWithIdentity(
    kdfID: UInt8,
    salt: Data,
    iterations: Int,
    wrappedUDKPassword: Data,
    wrappedUDKRecovery: Data,
    udk: SymmetricKey
) throws -> VaultHeader {
    let keyPair = generateIdentityKeyPair()
    let wrappedPrivateKey = try wrapIdentityPrivateKey(keyPair.privateKey, with: udk)

    return VaultHeader(
        kdfID: kdfID,
        salt: salt,
        iterations: iterations,
        wrappedUDKPassword: wrappedUDKPassword,
        wrappedUDKRecovery: wrappedUDKRecovery,
        identityAlgorithmID: Curve25519KeyPairGenerator.algorithmID,
        identityPublicKey: keyPair.publicKey,
        wrappedIdentityPrivateKey: wrappedPrivateKey
    )
}
