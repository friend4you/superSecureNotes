import XCTest

@testable import VaultRepositoryProtocol

final class AccessTokenProvidingTests: XCTestCase {
    func testMockSatisfiesContract() async throws {
        let provider = MockTokenProvider(token: "access-token")
        let token = try await provider.accessToken()
        XCTAssertEqual(token, "access-token")
    }
}

private struct MockTokenProvider: AccessTokenProviding {
    let token: String

    func accessToken() async throws -> String {
        token
    }
}
