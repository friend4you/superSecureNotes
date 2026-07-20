import Foundation
import SecureCryptoProtocol

public struct VaultHeader: Equatable, Sendable {
    public static let magic = Array("SSNV".utf8)
    public static let formatVersionV1: UInt8 = 1
    public static let formatVersionV2: UInt8 = 2
    public static let currentFormatVersion = formatVersionV2
    public static let saltLength = PBKDF2KeyDeriver.saltLength
    public static let identityPublicKeyLength = Curve25519KeyPairGenerator.publicKeyLength

    public let kdfID: UInt8
    public let salt: Data
    public let iterations: Int
    public let wrappedUDKPassword: Data
    public let wrappedUDKRecovery: Data
    public let identityAlgorithmID: UInt8?
    public let identityPublicKey: Data?
    public let wrappedIdentityPrivateKey: Data?

    public var hasIdentity: Bool {
        identityPublicKey != nil
    }

    public init(
        kdfID: UInt8,
        salt: Data,
        iterations: Int,
        wrappedUDKPassword: Data,
        wrappedUDKRecovery: Data,
        identityAlgorithmID: UInt8? = nil,
        identityPublicKey: Data? = nil,
        wrappedIdentityPrivateKey: Data? = nil
    ) {
        self.kdfID = kdfID
        self.salt = salt
        self.iterations = iterations
        self.wrappedUDKPassword = wrappedUDKPassword
        self.wrappedUDKRecovery = wrappedUDKRecovery
        self.identityAlgorithmID = identityAlgorithmID
        self.identityPublicKey = identityPublicKey
        self.wrappedIdentityPrivateKey = wrappedIdentityPrivateKey
    }

    public func serialized() throws -> Data {
        try validateFields()

        var buffer = ByteBuffer()
        buffer.appendFixedBytes(Data(Self.magic))
        buffer.appendUInt8(hasIdentity ? Self.formatVersionV2 : Self.formatVersionV1)
        buffer.appendUInt8(kdfID)
        buffer.appendFixedBytes(salt)
        buffer.appendUInt32BE(UInt32(iterations))
        try buffer.appendLengthPrefixedBytes(wrappedUDKPassword)
        try buffer.appendLengthPrefixedBytes(wrappedUDKRecovery)

        if hasIdentity {
            buffer.appendUInt8(identityAlgorithmID!)
            buffer.appendFixedBytes(identityPublicKey!)
            try buffer.appendLengthPrefixedBytes(wrappedIdentityPrivateKey!)
        }

        return buffer.bytes
    }

    public static func parse(_ data: Data) throws -> VaultHeader {
        var reader = ByteBuffer(data: data)
        try reader.expectMagic(Self.magic)

        let version = try reader.readUInt8()
        guard version == Self.formatVersionV1 || version == Self.formatVersionV2 else {
            throw SecureCryptoError.unsupportedVersion(version)
        }

        let kdfID = try reader.readUInt8()
        let salt = try reader.readFixedBytes(count: Self.saltLength)
        let iterations = Int(try reader.readUInt32BE())
        let wrappedUDKPassword = try reader.readLengthPrefixedBytes()
        let wrappedUDKRecovery = try reader.readLengthPrefixedBytes()

        var identityAlgorithmID: UInt8?
        var identityPublicKey: Data?
        var wrappedIdentityPrivateKey: Data?

        if version == Self.formatVersionV2 {
            identityAlgorithmID = try reader.readUInt8()
            identityPublicKey = try reader.readFixedBytes(count: Self.identityPublicKeyLength)
            wrappedIdentityPrivateKey = try reader.readLengthPrefixedBytes()
        }

        guard reader.isAtEnd else {
            throw SecureCryptoError.invalidInput("Vault header contains trailing bytes.")
        }

        let header = VaultHeader(
            kdfID: kdfID,
            salt: salt,
            iterations: iterations,
            wrappedUDKPassword: wrappedUDKPassword,
            wrappedUDKRecovery: wrappedUDKRecovery,
            identityAlgorithmID: identityAlgorithmID,
            identityPublicKey: identityPublicKey,
            wrappedIdentityPrivateKey: wrappedIdentityPrivateKey
        )
        try header.validateFields()
        return header
    }

    private func validateFields() throws {
        guard salt.count == Self.saltLength else {
            throw SecureCryptoError.invalidInput("Salt must be exactly \(Self.saltLength) bytes.")
        }
        guard iterations >= 0, iterations <= Int(UInt32.max) else {
            throw SecureCryptoError.invalidInput("Iterations must fit in a UInt32.")
        }

        let hasAlgorithmID = identityAlgorithmID != nil
        let hasPublicKey = identityPublicKey != nil
        let hasWrappedPrivateKey = wrappedIdentityPrivateKey != nil
        let identityPresentCount = [hasAlgorithmID, hasPublicKey, hasWrappedPrivateKey].filter { $0 }.count
        if identityPresentCount != 0, identityPresentCount != 3 {
            throw SecureCryptoError.invalidInput("Identity fields must all be present or all absent.")
        }

        if let identityPublicKey, identityPublicKey.count != Self.identityPublicKeyLength {
            throw SecureCryptoError.invalidInput(
                "Identity public key must be exactly \(Self.identityPublicKeyLength) bytes."
            )
        }
    }
}
