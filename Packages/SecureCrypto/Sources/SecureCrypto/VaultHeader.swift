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
        guard salt.count == Self.saltLength else {
            throw SecureCryptoError.invalidInput("Salt must be exactly \(Self.saltLength) bytes.")
        }
        guard iterations >= 0, iterations <= Int(UInt32.max) else {
            throw SecureCryptoError.invalidInput("Iterations must fit in a UInt32.")
        }

        var buffer = ByteBuffer()
        buffer.appendFixedBytes(Data(Self.magic))
        buffer.appendUInt8(Self.formatVersion)
        buffer.appendUInt8(kdfID)
        buffer.appendFixedBytes(salt)
        buffer.appendUInt32BE(UInt32(iterations))
        try buffer.appendLengthPrefixedBytes(wrappedUDKPassword)
        try buffer.appendLengthPrefixedBytes(wrappedUDKRecovery)
        return buffer.bytes
    }

    public static func parse(_ data: Data) throws -> VaultHeader {
        var reader = ByteBuffer(data: data)
        try reader.expectMagic(Self.magic)

        let version = try reader.readUInt8()
        guard version == Self.formatVersion else {
            throw SecureCryptoError.unsupportedVersion(version)
        }

        let kdfID = try reader.readUInt8()
        let salt = try reader.readFixedBytes(count: Self.saltLength)
        let iterations = Int(try reader.readUInt32BE())
        let wrappedUDKPassword = try reader.readLengthPrefixedBytes()
        let wrappedUDKRecovery = try reader.readLengthPrefixedBytes()

        guard reader.isAtEnd else {
            throw SecureCryptoError.invalidInput("Vault header contains trailing bytes.")
        }

        return VaultHeader(
            kdfID: kdfID,
            salt: salt,
            iterations: iterations,
            wrappedUDKPassword: wrappedUDKPassword,
            wrappedUDKRecovery: wrappedUDKRecovery
        )
    }
}
