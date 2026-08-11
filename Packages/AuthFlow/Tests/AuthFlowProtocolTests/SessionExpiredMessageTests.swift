import AuthFlowProtocol
import XCTest

final class SessionExpiredMessageTests: XCTestCase {
    func testMessageShownOnSessionExpiryLogout() {
        let notifier = SessionExpiredNotifier()
        notifier.flagSessionExpired()

        XCTAssertTrue(notifier.consumeSessionExpiredFlag())
    }

    func testUserInitiatedLogoutHasNoSessionExpiredMessage() {
        let notifier = SessionExpiredNotifier()

        XCTAssertFalse(notifier.consumeSessionExpiredFlag())
    }

    func testConsumeClearsSessionExpiredFlag() {
        let notifier = SessionExpiredNotifier()
        notifier.flagSessionExpired()

        XCTAssertTrue(notifier.consumeSessionExpiredFlag())
        XCTAssertFalse(notifier.consumeSessionExpiredFlag())
    }
}
