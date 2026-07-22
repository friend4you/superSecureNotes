import CryptoKit
import XCTest

@testable import VaultSession

final class VaultSessionLifecycleTests: XCTestCase {
    func testInitialStateIsInactive() async {
        let session = VaultSession()
        let isActive = await session.isActive
        XCTAssertFalse(isActive)
    }

    func testEstablishSetsActive() async {
        let session = VaultSession()
        await session.establish(sampleKeys())
        let isActive = await session.isActive
        XCTAssertTrue(isActive)
    }

    func testClearSetsInactive() async {
        let session = VaultSession()
        await session.establish(sampleKeys())
        await session.clear()
        let isActive = await session.isActive
        XCTAssertFalse(isActive)
    }

    func testClearWhenInactiveIsIdempotent() async {
        let session = VaultSession()
        await session.clear()
        let isActive = await session.isActive
        XCTAssertFalse(isActive)
    }

    func testEstablishReplacesKeysWhenAlreadyActive() async throws {
        let session = VaultSession()
        let firstKeys = VaultSessionKeys(
            udk: SymmetricKey(data: Data(repeating: 0x01, count: 32)),
            identityPrivateKey: Data(repeating: 0x02, count: 32)
        )
        let secondKeys = VaultSessionKeys(
            udk: SymmetricKey(data: Data(repeating: 0x03, count: 32)),
            identityPrivateKey: Data(repeating: 0x04, count: 32)
        )

        await session.establish(firstKeys)
        await session.establish(secondKeys)

        let isActive = await session.isActive
        XCTAssertTrue(isActive)

        let udk = try await session.udk()
        XCTAssertEqual(keyData(udk), keyData(secondKeys.udk))

        let identityKey = try await session.identityPrivateKey()
        XCTAssertEqual(identityKey, secondKeys.identityPrivateKey)
    }

    private func sampleKeys() -> VaultSessionKeys {
        VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
