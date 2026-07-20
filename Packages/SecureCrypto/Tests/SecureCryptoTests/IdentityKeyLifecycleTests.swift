import CryptoKit
import XCTest

@testable import SecureCrypto

final class IdentityKeyLifecycleTests: XCTestCase {
    func testUnwrapIdentityAfterPasswordUnlock() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)
        let unlockResult = try unlockVault(header: creation.header, password: password)

        let privateKey = try unwrapIdentityPrivateKey(header: unlockResult.header, udk: unlockResult.udk)
        let derivedPublicKey = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: privateKey
        ).publicKey.rawRepresentation

        XCTAssertEqual(derivedPublicKey, unlockResult.header.identityPublicKey)
    }

    func testUnwrapIdentityAfterMnemonicRecovery() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)
        let passwordUnlock = try unlockVault(header: creation.header, password: password)
        let recoveryUnlock = try recoverVault(header: creation.header, mnemonic: creation.mnemonic)

        let privateKeyFromPassword = try unwrapIdentityPrivateKey(
            header: passwordUnlock.header,
            udk: passwordUnlock.udk
        )
        let privateKeyFromRecovery = try unwrapIdentityPrivateKey(
            header: recoveryUnlock.header,
            udk: recoveryUnlock.udk
        )

        XCTAssertEqual(privateKeyFromPassword, privateKeyFromRecovery)
    }

    func testUnwrapFailsWithoutIdentityFields() throws {
        let header = VaultHeader(
            kdfID: PBKDF2KeyDeriver().algorithmID,
            salt: Data(repeating: 0xAA, count: VaultHeader.saltLength),
            iterations: PBKDF2KeyDeriver.defaultIterations,
            wrappedUDKPassword: Data(repeating: 0x01, count: 60),
            wrappedUDKRecovery: Data(repeating: 0x02, count: 60)
        )
        let udk = SymmetricKey(size: .bits256)

        XCTAssertThrowsError(try unwrapIdentityPrivateKey(header: header, udk: udk)) { error in
            XCTAssertEqual(
                error as? SecureCryptoError,
                .invalidInput("Vault header does not contain identity fields.")
            )
        }
    }
}
