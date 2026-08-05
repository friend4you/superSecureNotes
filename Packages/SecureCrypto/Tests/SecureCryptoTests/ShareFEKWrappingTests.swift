import CryptoKit
import XCTest

@testable import SecureCrypto

final class ShareFEKWrappingTests: XCTestCase {
    func testWrapFEKForRecipientProducesSSNFV1WireBlob() throws {
        let fek = generateSymmetricKey()
        let recipient = generateIdentityKeyPair()

        let wireBlob = try wrapFEKForRecipient(fek, recipientPublicKey: recipient.publicKey)

        XCTAssertEqual(Array(wireBlob.prefix(4)), Array("SSNF".utf8))
        XCTAssertEqual(wireBlob[4], 1) // version
        XCTAssertEqual(wireBlob[5], 1) // algorithm_id Curve25519
        XCTAssertEqual(wireBlob.count, 4 + 1 + 1 + 32 + 2 + (wireBlob.count - 40))
        let ephemeralPublicKey = wireBlob.subdata(in: 6 ..< 38)
        XCTAssertEqual(ephemeralPublicKey.count, 32)
        let wrappedLength = UInt16(wireBlob[38]) << 8 | UInt16(wireBlob[39])
        XCTAssertEqual(Int(wrappedLength), wireBlob.count - 40)
        XCTAssertGreaterThan(wrappedLength, 0)
    }

    func testWrapFEKForRecipientRejectsInvalidPublicKeyLength() {
        let fek = generateSymmetricKey()
        let shortKey = Data(repeating: 0x01, count: 16)
        let longKey = Data(repeating: 0x01, count: 64)

        XCTAssertThrowsError(try wrapFEKForRecipient(fek, recipientPublicKey: shortKey)) { error in
            guard case let .invalidInput(message) = error as? SecureCryptoError else {
                return XCTFail("Expected invalidInput, got \(error)")
            }
            XCTAssertTrue(message.lowercased().contains("32"))
        }

        XCTAssertThrowsError(try wrapFEKForRecipient(fek, recipientPublicKey: longKey)) { error in
            guard case let .invalidInput(message) = error as? SecureCryptoError else {
                return XCTFail("Expected invalidInput, got \(error)")
            }
            XCTAssertTrue(message.lowercased().contains("32"))
        }
    }

    func testWrapThenUnwrapSharedFEKRoundtrip() throws {
        let fek = generateSymmetricKey()
        let recipient = generateIdentityKeyPair()

        let wireBlob = try wrapFEKForRecipient(fek, recipientPublicKey: recipient.publicKey)
        let unwrapped = try unwrapSharedFEK(wireBlob, identityPrivateKey: recipient.privateKey)

        XCTAssertEqual(keyData(unwrapped), keyData(fek))
    }

    func testUnwrapSharedFEKRejectsInvalidMagic() throws {
        let fek = generateSymmetricKey()
        let recipient = generateIdentityKeyPair()
        var wireBlob = try wrapFEKForRecipient(fek, recipientPublicKey: recipient.publicKey)
        wireBlob[0] = 0x00

        XCTAssertThrowsError(try unwrapSharedFEK(wireBlob, identityPrivateKey: recipient.privateKey)) { error in
            guard case .invalidMagic = error as? SecureCryptoError else {
                return XCTFail("Expected invalidMagic, got \(error)")
            }
        }
    }

    func testUnwrapSharedFEKRejectsUnsupportedVersion() throws {
        let fek = generateSymmetricKey()
        let recipient = generateIdentityKeyPair()
        var wireBlob = try wrapFEKForRecipient(fek, recipientPublicKey: recipient.publicKey)
        wireBlob[4] = 99

        XCTAssertThrowsError(try unwrapSharedFEK(wireBlob, identityPrivateKey: recipient.privateKey)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .unsupportedVersion(99))
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
