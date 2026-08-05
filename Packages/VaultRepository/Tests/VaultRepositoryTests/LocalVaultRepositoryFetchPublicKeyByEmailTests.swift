import XCTest

@testable import VaultRepository
@testable import VaultRepositoryProtocol

final class LocalVaultRepositoryFetchPublicKeyByEmailTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        super.tearDown()
    }

    func testFetchPublicKeyByEmailReturnsThirtyTwoZeroBytes() async throws {
        let repository = LocalVaultRepository(vaultDirectoryURL: temporaryDirectory)

        let publicKey = try await repository.fetchPublicKey(email: "user@example.com")

        XCTAssertEqual(publicKey, Data(repeating: 0, count: 32))
        XCTAssertEqual(publicKey.count, 32)
    }
}
