import XCTest

@testable import SecureCrypto

final class VaultHeaderTests: XCTestCase {
    func testSerializeDeserializeRoundtrip() throws {
        let header = makeSampleHeader()

        let data = try header.serialized()
        let parsed = try VaultHeader.parse(data)

        XCTAssertEqual(parsed, header)
    }

    func testSerializedBytesStartWithMagicAndVersion() throws {
        let data = try makeSampleHeader().serialized()

        XCTAssertEqual(data.prefix(4), Data(VaultHeader.magic))
        XCTAssertEqual(data[4], VaultHeader.formatVersion)
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

    private func makeSampleHeader() -> VaultHeader {
        VaultHeader(
            kdfID: PBKDF2KeyDeriver().algorithmID,
            salt: Data(repeating: 0xAA, count: VaultHeader.saltLength),
            iterations: PBKDF2KeyDeriver.defaultIterations,
            wrappedUDKPassword: Data(repeating: 0x01, count: 60),
            wrappedUDKRecovery: Data(repeating: 0x02, count: 60)
        )
    }
}
