import XCTest

@testable import superSecureNotes

final class StubBackendConfigurationTests: XCTestCase {
    override func tearDown() {
        StubBackendConfiguration.testLaunchArguments = nil
        super.tearDown()
    }

    func testIsEnabledWhenLaunchArgumentPresent() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]

        XCTAssertTrue(StubBackendConfiguration.isEnabled)
    }

    func testIsDisabledWhenLaunchArgumentAbsent() {
        StubBackendConfiguration.testLaunchArguments = []

        XCTAssertFalse(StubBackendConfiguration.isEnabled)
    }
}
