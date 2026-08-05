import XCTest

@testable import VaultRepositoryProtocol

final class VaultRepositoryTests: XCTestCase {
    func testMockActorSatisfiesContract() async throws {
        let repository = MockVaultRepository()
        let header = Data([0x01, 0x02, 0x03])
        let publicKey = Data(repeating: 0xAB, count: 32)

        await repository.setHeader(header)
        await repository.setPublicKey(publicKey)

        let readHeader = try await repository.readHeader()
        XCTAssertEqual(readHeader, header)

        try await repository.writeHeader(Data([0x04]))
        let updatedHeader = try await repository.readHeader()
        XCTAssertEqual(updatedHeader, Data([0x04]))

        let fetchedKey = try await repository.fetchPublicKey(
            userID: "550e8400-e29b-41d4-a716-446655440000"
        )
        XCTAssertEqual(fetchedKey, publicKey)
    }
}

private actor MockVaultRepository: VaultRepository {
    private var header = Data()
    private var publicKey = Data()

    func setHeader(_ header: Data) {
        self.header = header
    }

    func setPublicKey(_ publicKey: Data) {
        self.publicKey = publicKey
    }

    func readHeader() async throws -> Data {
        header
    }

    func writeHeader(_ header: Data) async throws {
        self.header = header
    }

    func fetchPublicKey(userID: String) async throws -> Data {
        publicKey
    }

    func fetchPublicKey(email: String) async throws -> Data {
        publicKey
    }
}
