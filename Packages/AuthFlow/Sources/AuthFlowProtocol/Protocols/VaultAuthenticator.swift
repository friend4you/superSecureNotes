import Foundation
import VaultSessionProtocol

public struct VaultCreationOutcome: Equatable, Sendable {
    public let headerData: Data
    public let mnemonic: [String]

    public init(headerData: Data, mnemonic: [String]) {
        self.headerData = headerData
        self.mnemonic = mnemonic
    }
}

public struct VaultUnlockOutcome: Sendable {
    public let sessionKeys: VaultSessionKeys

    public init(sessionKeys: VaultSessionKeys) {
        self.sessionKeys = sessionKeys
    }
}

public protocol VaultAuthenticator: Sendable {
    func createVault(password: String) throws -> VaultCreationOutcome
    func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome
}
