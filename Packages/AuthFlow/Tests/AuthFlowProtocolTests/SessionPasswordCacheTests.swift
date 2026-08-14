import AuthFlowProtocol
import XCTest

@MainActor
final class SessionPasswordCacheTests: XCTestCase {
    func testStoreReturnsPassword() {
        let cache = SessionPasswordCache()

        cache.store("secret")

        XCTAssertEqual(cache.password(), "secret")
    }

    func testClearEmptiesCache() {
        let cache = SessionPasswordCache()
        cache.store("secret")

        cache.clear()

        XCTAssertNil(cache.password())
    }

    func testPasswordIsNilInitially() {
        let cache = SessionPasswordCache()

        XCTAssertNil(cache.password())
    }
}
