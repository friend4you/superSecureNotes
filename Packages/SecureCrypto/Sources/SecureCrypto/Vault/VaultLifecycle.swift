import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct VaultCreationResult: Equatable, Sendable {
    public let header: VaultHeader
    public let mnemonic: [String]

    public init(header: VaultHeader, mnemonic: [String]) {
        self.header = header
        self.mnemonic = mnemonic
    }
}

public struct VaultUnlockResult: Sendable {
    public let udk: SymmetricKey
    public let header: VaultHeader

    public init(udk: SymmetricKey, header: VaultHeader) {
        self.udk = udk
        self.header = header
    }
}

public func createVault(password: String) throws -> VaultCreationResult {
    guard !password.isEmpty else {
        throw SecureCryptoError.invalidInput("Password must not be empty.")
    }

    let passwordDeriver = PBKDF2KeyDeriver()
    let recoveryDeriver = HKDFRecoveryKeyDeriver()
    let keyWrapper = ChaChaPolyKeyWrapper()

    let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    let udk = generateSymmetricKey()
    let recoveryEntropy = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    let mnemonic = try BIP39Mnemonic.words(from: recoveryEntropy)

    let passwordKEK = try passwordDeriver.deriveKey(password: password, salt: salt)
    let recoveryKEK = try recoveryDeriver.deriveKey(entropy: recoveryEntropy)

    let wrappedUDKPassword = try keyWrapper.wrapKey(udk, with: passwordKEK)
    let wrappedUDKRecovery = try keyWrapper.wrapKey(udk, with: recoveryKEK)

    let header = try makeVaultHeaderWithIdentity(
        kdfID: passwordDeriver.algorithmID,
        salt: salt,
        iterations: passwordDeriver.iterations,
        wrappedUDKPassword: wrappedUDKPassword,
        wrappedUDKRecovery: wrappedUDKRecovery,
        udk: udk
    )

    return VaultCreationResult(header: header, mnemonic: mnemonic)
}

public func unlockVault(header: VaultHeader, password: String) throws -> VaultUnlockResult {
    let passwordDeriver = PBKDF2KeyDeriver(iterations: header.iterations)
    let keyWrapper = ChaChaPolyKeyWrapper()

    let passwordKEK = try passwordDeriver.deriveKey(password: password, salt: header.salt)
    let udk = try keyWrapper.unwrapKey(header.wrappedUDKPassword, with: passwordKEK)
    let upgradedHeader = try upgradeHeaderWithIdentity(header, udk: udk)

    return VaultUnlockResult(udk: udk, header: upgradedHeader)
}

public func recoverVault(header: VaultHeader, mnemonic: [String]) throws -> VaultUnlockResult {
    let recoveryDeriver = HKDFRecoveryKeyDeriver()
    let keyWrapper = ChaChaPolyKeyWrapper()

    let recoveryEntropy = try BIP39Mnemonic.validate(mnemonic)
    let recoveryKEK = try recoveryDeriver.deriveKey(entropy: recoveryEntropy)
    let udk = try keyWrapper.unwrapKey(header.wrappedUDKRecovery, with: recoveryKEK)
    let upgradedHeader = try upgradeHeaderWithIdentity(header, udk: udk)

    return VaultUnlockResult(udk: udk, header: upgradedHeader)
}

public func changePassword(
    header: VaultHeader,
    oldPassword: String,
    newPassword: String
) throws -> VaultHeader {
    guard !newPassword.isEmpty else {
        throw SecureCryptoError.invalidInput("Password must not be empty.")
    }

    let passwordDeriver = PBKDF2KeyDeriver(iterations: header.iterations)
    let keyWrapper = ChaChaPolyKeyWrapper()

    let unlockResult = try unlockVault(header: header, password: oldPassword)
    let newPasswordKEK = try passwordDeriver.deriveKey(password: newPassword, salt: header.salt)
    let wrappedUDKPassword = try keyWrapper.wrapKey(unlockResult.udk, with: newPasswordKEK)

    return VaultHeader(
        kdfID: unlockResult.header.kdfID,
        salt: unlockResult.header.salt,
        iterations: unlockResult.header.iterations,
        wrappedUDKPassword: wrappedUDKPassword,
        wrappedUDKRecovery: unlockResult.header.wrappedUDKRecovery,
        identityAlgorithmID: unlockResult.header.identityAlgorithmID,
        identityPublicKey: unlockResult.header.identityPublicKey,
        wrappedIdentityPrivateKey: unlockResult.header.wrappedIdentityPrivateKey
    )
}
