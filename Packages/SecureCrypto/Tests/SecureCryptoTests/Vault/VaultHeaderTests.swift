import XCTest

@testable import SecureCrypto

final class VaultHeaderTests: XCTestCase {
    func testSerializeDeserializeRoundtripV1() throws {
        let header = makeSampleV1Header()

        let data = try header.serialized()
        let parsed = try VaultHeader.parse(data)

        XCTAssertEqual(parsed, header)
        XCTAssertFalse(parsed.hasIdentity)
    }

    func testSerializeDeserializeRoundtripV2() throws {
        let header = makeSampleV2Header()

        let data = try header.serialized()
        let parsed = try VaultHeader.parse(data)

        XCTAssertEqual(parsed, header)
        XCTAssertTrue(parsed.hasIdentity)
    }

    func testV1SerializedBytesStartWithMagicAndVersion() throws {
        let data = try makeSampleV1Header().serialized()

        XCTAssertEqual(data.prefix(4), Data(VaultHeader.magic))
        XCTAssertEqual(data[4], VaultHeader.formatVersionV1)
    }

    func testV2SerializedBytesStartWithMagicAndVersion() throws {
        let data = try makeSampleV2Header().serialized()

        XCTAssertEqual(data.prefix(4), Data(VaultHeader.magic))
        XCTAssertEqual(data[4], VaultHeader.formatVersionV2)
    }

    func testRejectsInvalidMagic() {
        var data = Data(repeating: 0, count: 64)
        data.replaceSubrange(0 ..< 4, with: Data("XXXX".utf8))

        XCTAssertThrowsError(try VaultHeader.parse(data)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidMagic(expected: "SSNV", actual: "XXXX")
            )
        }
    }

    func testRejectsUnsupportedVersion() throws {
        var writer = ByteBuffer()
        writer.appendFixedBytes(Data(VaultHeader.magic))
        writer.appendUInt8(99)
        writer.appendUInt8(1)
        writer.appendFixedBytes(Data(repeating: 0xAA, count: 32))
        writer.appendUInt32BE(600_000)
        try writer.appendLengthPrefixedBytes(Data(repeating: 0x01, count: 60))
        try writer.appendLengthPrefixedBytes(Data(repeating: 0x02, count: 60))

        XCTAssertThrowsError(try VaultHeader.parse(writer.bytes)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .unsupportedVersion(99))
        }
    }

    func testV1HeaderRejectsTrailingBytes() throws {
        var data = try makeSampleV1Header().serialized()
        data.append(0xFF)

        XCTAssertThrowsError(try VaultHeader.parse(data)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidInput("Vault header contains trailing bytes.")
            )
        }
    }

    private func makeSampleV1Header() -> VaultHeader {
        VaultHeader(
            kdfID: PBKDF2KeyDeriver().algorithmID,
            salt: Data(repeating: 0xAA, count: VaultHeader.saltLength),
            iterations: PBKDF2KeyDeriver.defaultIterations,
            wrappedUDKPassword: Data(repeating: 0x01, count: 60),
            wrappedUDKRecovery: Data(repeating: 0x02, count: 60)
        )
    }

    private func makeSampleV2Header() -> VaultHeader {
        VaultHeader(
            kdfID: PBKDF2KeyDeriver().algorithmID,
            salt: Data(repeating: 0xAA, count: VaultHeader.saltLength),
            iterations: PBKDF2KeyDeriver.defaultIterations,
            wrappedUDKPassword: Data(repeating: 0x01, count: 60),
            wrappedUDKRecovery: Data(repeating: 0x02, count: 60),
            identityAlgorithmID: Curve25519KeyPairGenerator.algorithmID,
            identityPublicKey: Data(repeating: 0x11, count: VaultHeader.identityPublicKeyLength),
            wrappedIdentityPrivateKey: Data(repeating: 0x22, count: 60)
        )
    }
}
