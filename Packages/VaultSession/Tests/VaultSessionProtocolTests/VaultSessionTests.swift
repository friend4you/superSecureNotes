import CryptoKit
import XCTest

@testable import VaultSessionProtocol

final class VaultSessionContractTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let session = MockVaultSession()
        let initiallyActive = await session.isActive
        XCTAssertFalse(initiallyActive)

        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )

        await session.establish(keys)

        let activeAfterEstablish = await session.isActive
        XCTAssertTrue(activeAfterEstablish)

        let udk = try await session.udk()
        XCTAssertEqual(udk.bitCount, 256)

        let identityKey = try await session.identityPrivateKey()
        XCTAssertEqual(identityKey, keys.identityPrivateKey)

        await session.clear()

        let activeAfterClear = await session.isActive
        XCTAssertFalse(activeAfterClear)
    }
}

private actor MockVaultSession: VaultSession {
    private var storedKeys: VaultSessionKeys?

    var isActive: Bool {
        storedKeys != nil
    }

    nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { _ in }
    }

    func establish(_ keys: VaultSessionKeys) {
        storedKeys = keys
    }

    func clear() {
        storedKeys = nil
    }

    func udk() throws -> SymmetricKey {
        guard let storedKeys else {
            throw VaultSessionError.notActive
        }
        return storedKeys.udk
    }

    func identityPrivateKey() throws -> Data {
        guard let storedKeys else {
            throw VaultSessionError.notActive
        }
        return storedKeys.identityPrivateKey
    }
}
