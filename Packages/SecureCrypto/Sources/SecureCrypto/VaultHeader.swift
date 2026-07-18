import Foundation
import SecureCryptoProtocol

public struct VaultHeader: Equatable, Sendable {
    public static let magic = Array("SSNV".utf8)
    public static let formatVersion: UInt8 = 1
    public static let saltLength = PBKDF2KeyDeriver.saltLength

    public let kdfID: UInt8
    public let salt: Data
    public let iterations: Int
    public let wrappedUDKPassword: Data
    public let wrappedUDKRecovery: Data

    public init(
        kdfID: UInt8,
        salt: Data,
        iterations: Int,
        wrappedUDKPassword: Data,
        wrappedUDKRecovery: Data
    ) {
        self.kdfID = kdfID
        self.salt = salt
        self.iterations = iterations
        self.wrappedUDKPassword = wrappedUDKPassword
        self.wrappedUDKRecovery = wrappedUDKRecovery
    }

    public func serialized() throws -> Data {
        throw SecureCryptoError.invalidInput("VaultHeader serialization is not implemented.")
    }

    public static func parse(_ data: Data) throws -> VaultHeader {
        throw SecureCryptoError.invalidInput("VaultHeader parsing is not implemented.")
    }
}
