import XCTest

@testable import VaultSessionProtocol

final class VaultSessionErrorTests: XCTestCase {
    func testNotActiveIsEquatable() {
        XCTAssertEqual(VaultSessionError.notActive, VaultSessionError.notActive)
    }

    func testNotActiveIsSendable() {
        let error: any Error & Sendable = VaultSessionError.notActive
        XCTAssertTrue(error is VaultSessionError)
    }
}
