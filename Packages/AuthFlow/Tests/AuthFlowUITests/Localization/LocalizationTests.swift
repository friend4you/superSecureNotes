import AuthFlowUI
import XCTest

@testable import AuthFlowUI

final class LocalizationTests: XCTestCase {
    func testStringCatalogIsBundledWithAuthFlowUI() {
        XCTAssertTrue(AuthFlowUIBundleTesting.hasLocalizedCatalog)
    }
}
