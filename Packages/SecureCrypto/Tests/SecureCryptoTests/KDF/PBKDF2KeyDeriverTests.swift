import CryptoKit
import XCTest

@testable import SecureCrypto

final class PBKDF2KeyDeriverTests: XCTestCase {
    func testPBKDF2SHA256KnownVector() throws {
        let deriver = PBKDF2KeyDeriver(iterations: 1)
        let salt = Data("salt".utf8)
        let key = try deriver.deriveKey(password: "password", salt: salt)

        let expected = Data([
            0x12, 0x0f, 0xb6, 0xcf, 0xfc, 0xf8, 0xb3, 0x2c,
            0x43, 0xe7, 0x22, 0x52, 0x56, 0xc4, 0xf8, 0x37,
            0xa8, 0x65, 0x48, 0xc9, 0x2c, 0xcc, 0x35, 0x48,
            0x08, 0x05, 0x98, 0x7c, 0xb7, 0x0b, 0xe1, 0x7b,
        ])

        XCTAssertEqual(keyData(key), expected)
    }

    func testDeriveKeyWith32ByteSaltReturns256BitKey() throws {
        let deriver = PBKDF2KeyDeriver(iterations: 1)
        let salt = Data(repeating: 0x42, count: 32)
        let key = try deriver.deriveKey(password: "vault-password", salt: salt)

        XCTAssertEqual(key.bitCount, 256)
    }

    func testDefaultIterationCountIsAtLeast600k() {
        XCTAssertGreaterThanOrEqual(PBKDF2KeyDeriver.defaultIterations, 600_000)
    }

    func testSerializeParametersProducesStorableBlob() throws {
        let deriver = PBKDF2KeyDeriver()
        let salt = Data(repeating: 0x11, count: 32)
        let blob = try deriver.serializeParameters(salt: salt)

        XCTAssertEqual(blob.count, 1 + 4 + 32)
        XCTAssertEqual(blob[0], deriver.algorithmID)
        XCTAssertEqual(blob.dropFirst(1).prefix(4), Data([0x00, 0x09, 0x27, 0xC0]))
        XCTAssertEqual(blob.suffix(32), salt)
    }

    func testRejectsEmptySalt() {
        let deriver = PBKDF2KeyDeriver()

        XCTAssertThrowsError(try deriver.deriveKey(password: "password", salt: Data())) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Salt must not be empty."))
        }
    }

    func testSerializeParametersRejectsSaltThatIsNot32Bytes() {
        let deriver = PBKDF2KeyDeriver()

        XCTAssertThrowsError(try deriver.serializeParameters(salt: Data(repeating: 0, count: 16))) { error in
            XCTAssertEqual(error as? SecureCryptoError, .invalidInput("Salt must be exactly 32 bytes."))
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
