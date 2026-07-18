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

    let header = VaultHeader(
        kdfID: passwordDeriver.algorithmID,
        salt: salt,
        iterations: passwordDeriver.iterations,
        wrappedUDKPassword: wrappedUDKPassword,
        wrappedUDKRecovery: wrappedUDKRecovery
    )

    return VaultCreationResult(header: header, mnemonic: mnemonic)
}

public func unlockVault(header: VaultHeader, password: String) throws -> SymmetricKey {
    let passwordDeriver = PBKDF2KeyDeriver(iterations: header.iterations)
    let keyWrapper = ChaChaPolyKeyWrapper()

    let passwordKEK = try passwordDeriver.deriveKey(password: password, salt: header.salt)
    return try keyWrapper.unwrapKey(header.wrappedUDKPassword, with: passwordKEK)
}

public func recoverVault(header: VaultHeader, mnemonic: [String]) throws -> SymmetricKey {
    let recoveryDeriver = HKDFRecoveryKeyDeriver()
    let keyWrapper = ChaChaPolyKeyWrapper()

    let recoveryEntropy = try BIP39Mnemonic.validate(mnemonic)
    let recoveryKEK = try recoveryDeriver.deriveKey(entropy: recoveryEntropy)
    return try keyWrapper.unwrapKey(header.wrappedUDKRecovery, with: recoveryKEK)
}
