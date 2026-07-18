import CryptoKit
import XCTest

@testable import SecureCrypto

final class KeyWrappingTests: XCTestCase {
    func testChaChaPolyKeyWrapperConformsToKeyWrapping() throws {
        let wrapper = ChaChaPolyKeyWrapper()
        let wrappingKey = SymmetricKey(size: .bits256)
        let keyToWrap = SymmetricKey(size: .bits256)

        let wrapped = try wrapper.wrapKey(keyToWrap, with: wrappingKey)
        let unwrapped = try wrapper.unwrapKey(wrapped, with: wrappingKey)

        XCTAssertEqual(keyData(unwrapped), keyData(keyToWrap))
    }

    func testChaChaPolyKeyWrapperRejectsWrongKey() throws {
        let wrapper = ChaChaPolyKeyWrapper()
        let wrappingKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let keyToWrap = SymmetricKey(size: .bits256)

        let wrapped = try wrapper.wrapKey(keyToWrap, with: wrappingKey)

        XCTAssertThrowsError(try wrapper.unwrapKey(wrapped, with: wrongKey)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testWrapUnwrapRoundtrip() throws {
        let wrappingKey = SymmetricKey(size: .bits256)
        let keyToWrap = SymmetricKey(size: .bits256)

        let wrapped = try wrapKey(keyToWrap, with: wrappingKey)
        let unwrapped = try unwrapKey(wrapped, with: wrappingKey)

        XCTAssertEqual(keyData(unwrapped), keyData(keyToWrap))
    }

    func testWrongWrappingKeyFails() throws {
        let wrappingKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let keyToWrap = SymmetricKey(size: .bits256)

        let wrapped = try wrapKey(keyToWrap, with: wrappingKey)

        XCTAssertThrowsError(try unwrapKey(wrapped, with: wrongKey)) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
