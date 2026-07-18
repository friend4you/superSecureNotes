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
    throw SecureCryptoError.invalidInput("Vault creation is not implemented.")
}

public func unlockVault(header: VaultHeader, password: String) throws -> SymmetricKey {
    throw SecureCryptoError.invalidInput("Vault unlock is not implemented.")
}

public func recoverVault(header: VaultHeader, mnemonic: [String]) throws -> SymmetricKey {
    throw SecureCryptoError.invalidInput("Vault recovery is not implemented.")
}
