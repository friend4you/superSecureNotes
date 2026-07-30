import CredentialStore
import CredentialStoreProtocol
import XCTest

final class VaultHeaderCacheTests: XCTestCase {
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

    func testSaveAndReadVaultHeader() throws {
        let header = Data([0x01, 0x02, 0x03])
        try store.saveVaultHeader(header)
        XCTAssertEqual(store.vaultHeader(), header)
    }

    func testVaultHeaderUpdatedOnReSave() throws {
        try store.saveVaultHeader(Data([0x01]))
        try store.saveVaultHeader(Data([0x02, 0x03]))
        XCTAssertEqual(store.vaultHeader(), Data([0x02, 0x03]))
    }

    func testVaultHeaderClearedOnFullReset() throws {
        try store.saveVaultHeader(Data([0x01]))
        try store.clearAll()
        XCTAssertNil(store.vaultHeader())
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
