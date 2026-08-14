import AuthFlowProtocol
import XCTest

final class PendingBiometricEnrollmentStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.superSecureNotes.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSetPendingTruePersistsAcrossInstances() {
        let store = UserDefaultsPendingBiometricEnrollmentStore(defaults: defaults)
        store.setPending(true)

        let reloaded = UserDefaultsPendingBiometricEnrollmentStore(defaults: defaults)

        XCTAssertTrue(reloaded.isPending)
    }

    func testSetPendingFalseClearsFlag() {
        let store = UserDefaultsPendingBiometricEnrollmentStore(defaults: defaults)
        store.setPending(true)

        store.setPending(false)

        XCTAssertFalse(store.isPending)
    }

    func testIsPendingFalseByDefault() {
        let store = UserDefaultsPendingBiometricEnrollmentStore(defaults: defaults)

        XCTAssertFalse(store.isPending)
    }
}
