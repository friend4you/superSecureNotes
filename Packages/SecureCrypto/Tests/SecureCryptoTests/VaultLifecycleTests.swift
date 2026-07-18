import CryptoKit
import XCTest

@testable import SecureCrypto

final class VaultLifecycleTests: XCTestCase {
    func testCreateUnlockAndRecoverProduceSameUDK() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)

        XCTAssertEqual(creation.mnemonic.count, 12)

        let udkFromPassword = try unlockVault(header: creation.header, password: password)
        let udkFromMnemonic = try recoverVault(header: creation.header, mnemonic: creation.mnemonic)

        XCTAssertEqual(keyData(udkFromPassword), keyData(udkFromMnemonic))
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
