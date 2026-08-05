import CryptoKit
import Foundation
import SecureCryptoProtocol

private let shareFEKMagic: [UInt8] = [0x53, 0x53, 0x4E, 0x46] // "SSNF"
private let shareFEKVersion: UInt8 = 1
private let shareFEKAlgorithmID: UInt8 = 1 // Curve25519
private let shareFEKHKDFInfo = Data("superSecureNotes.share.fek.v1".utf8)
private let curve25519KeyLength = 32

/// Wraps a note FEK for a recipient's X25519 public key.
///
/// Wire format:
/// ```
/// magic "SSNF" (4) | version 1 (1) | algorithm_id 1 (1) | ephemeral_public_key (32)
/// | wrapped_fek_length UInt16 BE | wrapped_fek_bytes
/// ```
public func wrapFEKForRecipient(_ fek: SymmetricKey, recipientPublicKey: Data) throws -> Data {
    guard recipientPublicKey.count == curve25519KeyLength else {
        throw SecureCryptoError.invalidInput(
            "Recipient public key must be exactly \(curve25519KeyLength) bytes."
        )
    }

    let recipientPublic: Curve25519.KeyAgreement.PublicKey
    do {
        recipientPublic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPublicKey)
    } catch {
        throw SecureCryptoError.invalidInput("Recipient public key is not a valid Curve25519 key.")
    }

    let ephemeralPrivate = Curve25519.KeyAgreement.PrivateKey()
    let sharedSecret = try ephemeralPrivate.sharedSecretFromKeyAgreement(with: recipientPublic)
    let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
        using: SHA256.self,
        salt: Data(),
        sharedInfo: shareFEKHKDFInfo,
        outputByteCount: 32
    )
    let wrappedFEK = try wrapKey(fek, with: wrappingKey)

    guard wrappedFEK.count <= UInt16.max else {
        throw SecureCryptoError.invalidInput("Wrapped FEK exceeds UInt16 length capacity.")
    }

    var buffer = ByteBuffer()
    buffer.appendFixedBytes(Data(shareFEKMagic))
    buffer.appendUInt8(shareFEKVersion)
    buffer.appendUInt8(shareFEKAlgorithmID)
    buffer.appendFixedBytes(ephemeralPrivate.publicKey.rawRepresentation)
    buffer.appendUInt16BE(UInt16(wrappedFEK.count))
    buffer.appendFixedBytes(wrappedFEK)
    return buffer.bytes
}

/// Unwraps a share-grant FEK wire blob using the recipient's identity private key.
public func unwrapSharedFEK(_ wrapped: Data, identityPrivateKey: Data) throws -> SymmetricKey {
    guard identityPrivateKey.count == curve25519KeyLength else {
        throw SecureCryptoError.invalidInput(
            "Identity private key must be exactly \(curve25519KeyLength) bytes."
        )
    }

    var buffer = ByteBuffer(data: wrapped)
    try buffer.expectMagic(shareFEKMagic)

    let version = try buffer.readUInt8()
    guard version == shareFEKVersion else {
        throw SecureCryptoError.unsupportedVersion(version)
    }

    let algorithmID = try buffer.readUInt8()
    guard algorithmID == shareFEKAlgorithmID else {
        throw SecureCryptoError.invalidInput("Unsupported share FEK algorithm ID: \(algorithmID).")
    }

    let ephemeralPublicKeyData = try buffer.readFixedBytes(count: curve25519KeyLength)
    let wrappedLength = Int(try buffer.readUInt16BE())
    let wrappedFEKBytes = try buffer.readFixedBytes(count: wrappedLength)

    guard buffer.isAtEnd else {
        throw SecureCryptoError.invalidInput("Trailing bytes after share FEK wire blob.")
    }

    let identityPrivate: Curve25519.KeyAgreement.PrivateKey
    do {
        identityPrivate = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityPrivateKey)
    } catch {
        throw SecureCryptoError.invalidInput("Identity private key is not a valid Curve25519 key.")
    }

    let ephemeralPublic: Curve25519.KeyAgreement.PublicKey
    do {
        ephemeralPublic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicKeyData)
    } catch {
        throw SecureCryptoError.invalidInput("Ephemeral public key is not a valid Curve25519 key.")
    }

    let sharedSecret = try identityPrivate.sharedSecretFromKeyAgreement(with: ephemeralPublic)
    let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
        using: SHA256.self,
        salt: Data(),
        sharedInfo: shareFEKHKDFInfo,
        outputByteCount: 32
    )
    return try unwrapKey(wrappedFEKBytes, with: wrappingKey)
}
