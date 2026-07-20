import CryptoKit
import XCTest

@testable import SecureCrypto

final class VaultLifecycleTests: XCTestCase {
    func testCreateUnlockAndRecoverProduceSameUDK() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)

        XCTAssertEqual(creation.mnemonic.count, 12)
        XCTAssertTrue(creation.header.hasIdentity)

        let passwordUnlock = try unlockVault(header: creation.header, password: password)
        let mnemonicUnlock = try recoverVault(header: creation.header, mnemonic: creation.mnemonic)

        XCTAssertEqual(keyData(passwordUnlock.udk), keyData(mnemonicUnlock.udk))
    }

    func testCreateVaultProducesUniqueIdentityPerVault() throws {
        let first = try createVault(password: "password-one")
        let second = try createVault(password: "password-two")

        XCTAssertNotEqual(first.header.identityPublicKey, second.header.identityPublicKey)
        XCTAssertNotEqual(
            first.header.wrappedIdentityPrivateKey,
            second.header.wrappedIdentityPrivateKey
        )
    }

    func testV1VaultUnlockUpgradesToV2() throws {
        let password = "vault-password"
        let v1Header = try makeV1VaultHeader(password: password)

        XCTAssertFalse(v1Header.hasIdentity)

        let unlockResult = try unlockVault(header: v1Header, password: password)

        XCTAssertTrue(unlockResult.header.hasIdentity)
        XCTAssertEqual(unlockResult.header.identityAlgorithmID, Curve25519KeyPairGenerator.algorithmID)
        XCTAssertEqual(unlockResult.header.identityPublicKey?.count, VaultHeader.identityPublicKeyLength)
        XCTAssertFalse(unlockResult.header.wrappedIdentityPrivateKey?.isEmpty ?? true)
    }

    func testV1VaultRecoveryUpgradesToV2() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)
        let v1Header = VaultHeader(
            kdfID: creation.header.kdfID,
            salt: creation.header.salt,
            iterations: creation.header.iterations,
            wrappedUDKPassword: creation.header.wrappedUDKPassword,
            wrappedUDKRecovery: creation.header.wrappedUDKRecovery
        )

        let recoveryResult = try recoverVault(header: v1Header, mnemonic: creation.mnemonic)

        XCTAssertTrue(recoveryResult.header.hasIdentity)
    }

    func testChangePasswordPreservesUDK() throws {
        let oldPassword = "old-password"
        let newPassword = "new-password"
        let creation = try createVault(password: oldPassword)
        let originalUnlock = try unlockVault(header: creation.header, password: oldPassword)

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )

        let newUnlock = try unlockVault(header: updatedHeader, password: newPassword)
        XCTAssertEqual(keyData(originalUnlock.udk), keyData(newUnlock.udk))
        XCTAssertEqual(updatedHeader.salt, creation.header.salt)
        XCTAssertEqual(updatedHeader.wrappedUDKRecovery, creation.header.wrappedUDKRecovery)
        XCTAssertNotEqual(updatedHeader.wrappedUDKPassword, creation.header.wrappedUDKPassword)
    }

    func testChangePasswordPreservesIdentity() throws {
        let oldPassword = "old-password"
        let newPassword = "new-password"
        let creation = try createVault(password: oldPassword)

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )

        XCTAssertEqual(updatedHeader.identityPublicKey, creation.header.identityPublicKey)
        XCTAssertEqual(
            updatedHeader.wrappedIdentityPrivateKey,
            creation.header.wrappedIdentityPrivateKey
        )

        let unlockResult = try unlockVault(header: updatedHeader, password: newPassword)
        let privateKey = try unwrapIdentityPrivateKey(header: unlockResult.header, udk: unlockResult.udk)
        let derivedPublicKey = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: privateKey
        ).publicKey.rawRepresentation

        XCTAssertEqual(derivedPublicKey, creation.header.identityPublicKey)
    }

    func testChangePasswordRejectsWrongOldPassword() throws {
        let creation = try createVault(password: "correct-password")

        XCTAssertThrowsError(
            try changePassword(
                header: creation.header,
                oldPassword: "wrong-password",
                newPassword: "new-password"
            )
        ) { error in
            XCTAssertEqual(error as? SecureCryptoError, .authenticationFailed)
        }
    }

    func testChangePasswordPreservesNoteDecryptability() throws {
        let oldPassword = "old-password"
        let newPassword = "new-password"
        let creation = try createVault(password: oldPassword)
        let unlockResult = try unlockVault(header: creation.header, password: oldPassword)

        let fek = generateSymmetricKey()
        let wrappedFEK = try wrapKey(fek, with: unlockResult.udk)
        let notePayload = Data("secret note body".utf8)
        let encryptedNote = try encrypt(notePayload, key: fek)

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )
        let unlockAfterChange = try unlockVault(header: updatedHeader, password: newPassword)

        let unwrappedFEK = try unwrapKey(wrappedFEK, with: unlockAfterChange.udk)
        let decryptedNote = try decrypt(encryptedNote, key: unwrappedFEK)

        XCTAssertEqual(decryptedNote, notePayload)
    }

    func testFullFlowCreateUnlockChangePasswordPreservesIdentity() throws {
        let oldPassword = "old-password"
        let newPassword = "new-password"
        let creation = try createVault(password: oldPassword)

        let firstUnlock = try unlockVault(header: creation.header, password: oldPassword)
        let firstPrivateKey = try unwrapIdentityPrivateKey(
            header: firstUnlock.header,
            udk: firstUnlock.udk
        )

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )
        let secondUnlock = try unlockVault(header: updatedHeader, password: newPassword)
        let secondPrivateKey = try unwrapIdentityPrivateKey(
            header: secondUnlock.header,
            udk: secondUnlock.udk
        )

        XCTAssertEqual(firstPrivateKey, secondPrivateKey)
        XCTAssertEqual(firstUnlock.header.identityPublicKey, secondUnlock.header.identityPublicKey)
    }

    func testFullFlowCreateRecoverProducesSameIdentity() throws {
        let password = "vault-password"
        let creation = try createVault(password: password)

        let passwordUnlock = try unlockVault(header: creation.header, password: password)
        let recoveryUnlock = try recoverVault(header: creation.header, mnemonic: creation.mnemonic)

        let passwordPrivateKey = try unwrapIdentityPrivateKey(
            header: passwordUnlock.header,
            udk: passwordUnlock.udk
        )
        let recoveryPrivateKey = try unwrapIdentityPrivateKey(
            header: recoveryUnlock.header,
            udk: recoveryUnlock.udk
        )

        XCTAssertEqual(passwordPrivateKey, recoveryPrivateKey)
        XCTAssertEqual(passwordUnlock.header.identityPublicKey, recoveryUnlock.header.identityPublicKey)
    }

    private func makeV1VaultHeader(password: String) throws -> VaultHeader {
        let creation = try createVault(password: password)
        return VaultHeader(
            kdfID: creation.header.kdfID,
            salt: creation.header.salt,
            iterations: creation.header.iterations,
            wrappedUDKPassword: creation.header.wrappedUDKPassword,
            wrappedUDKRecovery: creation.header.wrappedUDKRecovery
        )
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
