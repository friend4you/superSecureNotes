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

    func testChangePasswordPreservesUDK() throws {
        let oldPassword = "old-password"
        let newPassword = "new-password"
        let creation = try createVault(password: oldPassword)
        let originalUDK = try unlockVault(header: creation.header, password: oldPassword)

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )

        let udkFromNewPassword = try unlockVault(header: updatedHeader, password: newPassword)
        XCTAssertEqual(keyData(originalUDK), keyData(udkFromNewPassword))
        XCTAssertEqual(updatedHeader.salt, creation.header.salt)
        XCTAssertEqual(updatedHeader.wrappedUDKRecovery, creation.header.wrappedUDKRecovery)
        XCTAssertNotEqual(updatedHeader.wrappedUDKPassword, creation.header.wrappedUDKPassword)
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
        let udk = try unlockVault(header: creation.header, password: oldPassword)

        let fek = generateSymmetricKey()
        let wrappedFEK = try wrapKey(fek, with: udk)
        let notePayload = Data("secret note body".utf8)
        let encryptedNote = try encrypt(notePayload, key: fek)

        let updatedHeader = try changePassword(
            header: creation.header,
            oldPassword: oldPassword,
            newPassword: newPassword
        )
        let udkAfterChange = try unlockVault(header: updatedHeader, password: newPassword)

        let unwrappedFEK = try unwrapKey(wrappedFEK, with: udkAfterChange)
        let decryptedNote = try decrypt(encryptedNote, key: unwrappedFEK)

        XCTAssertEqual(decryptedNote, notePayload)
    }

    private func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}
