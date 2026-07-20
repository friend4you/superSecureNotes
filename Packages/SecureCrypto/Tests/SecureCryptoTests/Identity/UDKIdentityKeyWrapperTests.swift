import CryptoKit
import XCTest

@testable import SecureCrypto

final class UDKIdentityKeyWrapperTests: XCTestCase {
    func testWrapUnwrapRoundtrip() throws {
        let wrapper = UDKIdentityKeyWrapper()
        let udk = SymmetricKey(size: .bits256)
        let privateKey = Data(repeating: 0xCD, count: 32)

        let wrapped = try wrapper.wrapPrivateKey(privateKey, with: udk)
        let unwrapped = try wrapper.unwrapPrivateKey(wrapped, with: udk)

        XCTAssertEqual(unwrapped, privateKey)
    }

    func testWrongUDKFailsUnwrap() throws {
        let wrapper = UDKIdentityKeyWrapper()
        let udk = SymmetricKey(size: .bits256)
        let wrongUDK = SymmetricKey(size: .bits256)
        let privateKey = Data(repeating: 0xCD, count: 32)

        let wrapped = try wrapper.wrapPrivateKey(privateKey, with: udk)

        XCTAssertThrowsError(try wrapper.unwrapPrivateKey(wrapped, with: wrongUDK)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testTamperedBlobFailsUnwrap() throws {
        let wrapper = UDKIdentityKeyWrapper()
        let udk = SymmetricKey(size: .bits256)
        let privateKey = Data(repeating: 0xCD, count: 32)

        var wrapped = try wrapper.wrapPrivateKey(privateKey, with: udk)
        wrapped[wrapped.count - 1] ^= 0xFF

        XCTAssertThrowsError(try wrapper.unwrapPrivateKey(wrapped, with: udk)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }
}
