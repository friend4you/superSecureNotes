import CommonCrypto
import CryptoKit
import Foundation

public protocol PasswordKeyDeriving: Sendable {
    var algorithmID: UInt8 { get }
    var iterations: Int { get }

    func deriveKey(password: String, salt: Data) throws -> SymmetricKey
    func serializeParameters(salt: Data) throws -> Data
}

public struct PBKDF2KeyDeriver: PasswordKeyDeriving {
    public static let defaultIterations = 600_000
    public static let saltLength = 32
    public static let derivedKeyLength = 32

    public let algorithmID: UInt8 = 1
    public let iterations: Int

    public init(iterations: Int = defaultIterations) {
        self.iterations = iterations
    }

    public func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard !salt.isEmpty else {
            throw SecureCryptoError.invalidInput("Salt must not be empty.")
        }
        let derived = try pbkdf2(
            password: password,
            salt: salt,
            iterations: iterations,
            keyLength: Self.derivedKeyLength
        )
        return SymmetricKey(data: derived)
    }

    public func serializeParameters(salt: Data) throws -> Data {
        try validateVaultSalt(salt)
        var buffer = ByteBuffer()
        buffer.appendUInt8(algorithmID)
        buffer.appendUInt32BE(UInt32(iterations))
        buffer.appendFixedBytes(salt)
        return buffer.bytes
    }

    private func validateVaultSalt(_ salt: Data) throws {
        guard salt.count == Self.saltLength else {
            throw SecureCryptoError.invalidInput("Salt must be exactly 32 bytes.")
        }
    }

    private func pbkdf2(
        password: String,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKey = Data(count: keyLength)
        let passwordData = Data(password.utf8)

        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw SecureCryptoError.invalidInput("PBKDF2 key derivation failed.")
        }

        return derivedKey
    }
}
