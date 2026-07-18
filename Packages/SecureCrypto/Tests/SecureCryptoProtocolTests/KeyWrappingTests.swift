import CryptoKit
import XCTest

@testable import SecureCryptoProtocol

final class KeyWrappingProtocolTests: XCTestCase {
    func testMockWrapUnwrapRoundtrip() throws {
        let wrapper = MockKeyWrapper()
        let wrappingKey = SymmetricKey(size: .bits256)
        let keyToWrap = SymmetricKey(size: .bits256)

        let wrapped = try wrapper.wrapKey(keyToWrap, with: wrappingKey)
        let unwrapped = try wrapper.unwrapKey(wrapped, with: wrappingKey)

        XCTAssertEqual(keyData(unwrapped), keyData(keyToWrap))
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}

private struct MockKeyWrapper: KeyWrapping {
    func wrapKey(_ key: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    func unwrapKey(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
        SymmetricKey(data: wrapped)
    }
}
