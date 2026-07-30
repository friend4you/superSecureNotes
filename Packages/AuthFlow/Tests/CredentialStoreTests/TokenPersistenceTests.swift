import CredentialStore
import CredentialStoreProtocol
import XCTest

final class TokenPersistenceTests: XCTestCase {
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

    func testSaveAndReadEmail() throws {
        try store.saveEmail("user@example.com")
        XCTAssertEqual(store.email(), "user@example.com")
    }

    func testSaveAndReadRefreshToken() throws {
        try store.saveRefreshToken("refresh-token")
        XCTAssertEqual(store.refreshToken(), "refresh-token")
    }

    func testEmailClearedOnFullReset() throws {
        try store.saveEmail("user@example.com")
        try store.clearAll()
        XCTAssertNil(store.email())
    }

    func testRefreshTokenClearedOnFullReset() throws {
        try store.saveRefreshToken("refresh-token")
        try store.clearAll()
        XCTAssertNil(store.refreshToken())
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
