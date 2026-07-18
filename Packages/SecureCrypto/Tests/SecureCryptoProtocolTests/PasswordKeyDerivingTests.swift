import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class PasswordKeyDerivingTests: XCTestCase {
    func testMockConformingTypeSatisfiesContract() throws {
        let deriver = MockPasswordKeyDeriver()
        let salt = Data(repeating: 0x42, count: 32)

        XCTAssertEqual(deriver.algorithmID, 99)
        XCTAssertEqual(deriver.iterations, 1_000)

        let key = try deriver.deriveKey(password: "secret", salt: salt)
        XCTAssertEqual(key.bitCount, 256)

        let params = try deriver.serializeParameters(salt: salt)
        XCTAssertEqual(params, Data([99]) + salt)
    }
}

private struct MockPasswordKeyDeriver: PasswordKeyDeriving {
    let algorithmID: UInt8 = 99
    let iterations = 1_000

    func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        let material = Data(password.utf8) + salt
        return SymmetricKey(data: material.prefix(32))
    }

    func serializeParameters(salt: Data) throws -> Data {
        Data([algorithmID]) + salt
    }
}
