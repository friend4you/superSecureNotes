import CryptoKit
import XCTest

@testable import VaultSessionProtocol

final class VaultSessionKeysTests: XCTestCase {
    func testStoresUDKAndIdentityPrivateKey() {
        let udk = SymmetricKey(size: .bits256)
        let identityPrivateKey = Data(repeating: 0xAB, count: 32)
        let keys = VaultSessionKeys(udk: udk, identityPrivateKey: identityPrivateKey)

        XCTAssertEqual(keyData(keys.udk), keyData(udk))
        XCTAssertEqual(keys.identityPrivateKey, identityPrivateKey)
    }

    func testEquatableComparesUDKAndIdentityPrivateKey() {
        let udk = SymmetricKey(data: Data(repeating: 0x01, count: 32))
        let identityPrivateKey = Data(repeating: 0x02, count: 32)
        let first = VaultSessionKeys(udk: udk, identityPrivateKey: identityPrivateKey)
        let second = VaultSessionKeys(udk: udk, identityPrivateKey: identityPrivateKey)
        let different = VaultSessionKeys(
            udk: SymmetricKey(data: Data(repeating: 0x03, count: 32)),
            identityPrivateKey: identityPrivateKey
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testIsSendable() {
        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
        let sendKeys: VaultSessionKeys = keys
        XCTAssertEqual(sendKeys.identityPrivateKey.count, 32)
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
