import AuthFlowUI
import SecureCrypto
import XCTest

final class SecureCryptoVaultAuthenticatorTests: XCTestCase {
    func testCreateVaultReturnsSerializedHeaderAndMnemonic() throws {
        let authenticator = SecureCryptoVaultAuthenticator()
        let outcome = try authenticator.createVault(password: "test-password-123")

        XCTAssertFalse(outcome.headerData.isEmpty)
        XCTAssertFalse(outcome.mnemonic.isEmpty)
        _ = try VaultHeader.parse(outcome.headerData)
    }

    func testUnlockVaultReturnsVaultSessionKeys() throws {
        let authenticator = SecureCryptoVaultAuthenticator()
        let creation = try authenticator.createVault(password: "test-password-123")
        let unlock = try authenticator.unlockVault(
            headerData: creation.headerData,
            password: "test-password-123"
        )

        XCTAssertEqual(unlock.sessionKeys.identityPrivateKey.count, 32)
    }
}
