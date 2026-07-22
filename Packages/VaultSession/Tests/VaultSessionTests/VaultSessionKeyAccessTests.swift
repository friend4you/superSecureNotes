import CryptoKit
import XCTest

@testable import VaultSession

final class VaultSessionKeyAccessTests: XCTestCase {
    func testReadKeysWhenActive() async throws {
        let session = VaultSession()
        let keys = VaultSessionKeys(
            udk: SymmetricKey(data: Data(repeating: 0x11, count: 32)),
            identityPrivateKey: Data(repeating: 0x22, count: 32)
        )

        await session.establish(keys)

        let udk = try await session.udk()
        XCTAssertEqual(keyData(udk), keyData(keys.udk))

        let identityKey = try await session.identityPrivateKey()
        XCTAssertEqual(identityKey, keys.identityPrivateKey)
    }

    func testUDKThrowsWhenInactive() async {
        let session = VaultSession()

        do {
            _ = try await session.udk()
            XCTFail("Expected VaultSessionError.notActive")
        } catch {
            XCTAssertEqual(error as? VaultSessionError, .notActive)
        }
    }

    func testIdentityPrivateKeyThrowsWhenInactive() async {
        let session = VaultSession()

        do {
            _ = try await session.identityPrivateKey()
            XCTFail("Expected VaultSessionError.notActive")
        } catch {
            XCTAssertEqual(error as? VaultSessionError, .notActive)
        }
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
