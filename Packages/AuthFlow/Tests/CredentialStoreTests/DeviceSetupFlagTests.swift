import CredentialStore
import CredentialStoreProtocol
import XCTest

final class DeviceSetupFlagTests: XCTestCase {
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

    func testInitialStateIsNotSetUp() {
        XCTAssertFalse(store.hasLocalSetup)
    }

    func testMarkSetupCompleteSetsTrue() throws {
        try store.markSetupComplete()
        XCTAssertTrue(store.hasLocalSetup)
    }

    func testClearAllResetsSetupFlag() throws {
        try store.markSetupComplete()
        try store.clearAll()
        XCTAssertFalse(store.hasLocalSetup)
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
