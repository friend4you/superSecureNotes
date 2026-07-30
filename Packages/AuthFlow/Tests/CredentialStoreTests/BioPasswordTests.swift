import CredentialStore
import CredentialStoreProtocol
import XCTest

final class BioPasswordTests: XCTestCase {
    private var store: KeychainCredentialStore!

    override func setUp() {
        super.setUp()
        store = KeychainCredentialStore(
            service: uniqueService(),
            passwordAccessMode: .standard
        )
    }

    override func tearDown() {
        try? store.clearAll()
        store = nil
        super.tearDown()
    }

    func testBioEnabledDefaultsFalse() {
        XCTAssertFalse(store.bioEnabled())
    }

    func testSavePasswordWithBiometricsEnabled() throws {
        try store.setBioEnabled(true)
        try store.savePassword("secret")
        XCTAssertEqual(try store.loadPasswordWithBiometrics(), "secret")
    }

    func testPasswordItemRemovedWhenBiometricsDisabled() throws {
        try store.setBioEnabled(true)
        try store.savePassword("secret")
        try store.setBioEnabled(false)
        XCTAssertFalse(store.bioEnabled())
        XCTAssertThrowsError(try store.loadPasswordWithBiometrics()) { error in
            XCTAssertEqual(error as? CredentialStoreError, .itemNotFound)
        }
    }

    func testPasswordNotStoredWhenBiometricsNeverEnabled() {
        XCTAssertThrowsError(try store.savePassword("secret")) { error in
            XCTAssertEqual(error as? CredentialStoreError, .storageFailed)
        }
        XCTAssertThrowsError(try store.loadPasswordWithBiometrics()) { error in
            XCTAssertEqual(error as? CredentialStoreError, .itemNotFound)
        }
    }

    func testBioFlagUpdatedOnEnable() throws {
        try store.setBioEnabled(true)
        XCTAssertTrue(store.bioEnabled())
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
