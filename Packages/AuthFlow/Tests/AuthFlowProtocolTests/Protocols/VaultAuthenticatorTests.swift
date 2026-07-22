import AuthFlowProtocol
import CryptoKit
import VaultSessionProtocol
import XCTest

final class VaultAuthenticatorTests: XCTestCase {
    func testVaultCreationOutcomeHoldsExpectedFields() {
        let outcome = VaultCreationOutcome(headerData: Data([0x01]), mnemonic: ["abandon", "ability"])
        XCTAssertEqual(outcome.headerData, Data([0x01]))
        XCTAssertEqual(outcome.mnemonic, ["abandon", "ability"])
    }

    func testVaultUnlockOutcomeHoldsSessionKeys() {
        let keys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x02, count: 32)
        )
        let outcome = VaultUnlockOutcome(sessionKeys: keys)
        XCTAssertEqual(outcome.sessionKeys, keys)
    }

    func testMockVaultAuthenticatorSatisfiesProtocol() throws {
        let authenticator = MockVaultAuthenticator()
        let creation = try authenticator.createVault(password: "secret")
        XCTAssertEqual(creation.headerData, Data([0x0A]))

        let unlock = try authenticator.unlockVault(headerData: Data([0x0A]), password: "secret")
        XCTAssertEqual(unlock.sessionKeys.identityPrivateKey, Data(repeating: 0x01, count: 32))
    }
}
