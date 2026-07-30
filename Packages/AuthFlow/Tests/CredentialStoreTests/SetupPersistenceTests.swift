import CredentialStore
import CredentialStoreProtocol
import XCTest

final class SetupPersistenceTests: XCTestCase {
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

    func testSaveSetupMarksDeviceReady() throws {
        let header = Data([0x0A, 0x0B])
        try store.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: header
        )

        XCTAssertTrue(store.hasLocalSetup)
        XCTAssertEqual(store.email(), "user@example.com")
        XCTAssertEqual(store.refreshToken(), "refresh-token")
        XCTAssertEqual(store.vaultHeader(), header)
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
