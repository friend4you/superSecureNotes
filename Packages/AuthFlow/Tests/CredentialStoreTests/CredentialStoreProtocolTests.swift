import CredentialStore
import CredentialStoreProtocol
import XCTest

final class CredentialStoreProtocolTests: XCTestCase {
    func testCredentialStoreProtocolCompiles() {
        let store: any CredentialStore = KeychainCredentialStore(
            service: uniqueService(),
            passwordAccessMode: .standard
        )
        XCTAssertFalse(store.hasLocalSetup)
    }

    func testCredentialStoreErrorIsEquatableAndSendable() {
        let lhs: CredentialStoreError = .itemNotFound
        let rhs: CredentialStoreError = .itemNotFound
        XCTAssertEqual(lhs, rhs)

        let sendable: any Sendable = CredentialStoreError.storageFailed
        XCTAssertNotNil(sendable)
    }

    private func uniqueService() -> String {
        "com.superSecureNotes.tests.\(UUID().uuidString)"
    }
}
