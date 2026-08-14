import Foundation
import VaultRepositoryProtocol

public actor NetworkVaultRepository: VaultRepository {
    private let apiClient: VaultAPIClient

    public init(apiClient: VaultAPIClient) {
        self.apiClient = apiClient
    }

    public func readHeader() async throws -> Data {
        try await apiClient.readHeader()
    }

    public func writeHeader(_ header: Data) async throws {
        guard !header.isEmpty else {
            throw VaultRepositoryError.validationError("Vault header must not be empty.")
        }

        try await apiClient.writeHeader(header)
    }

    public func fetchPublicKey(email: String) async throws -> Data {
        guard !email.isEmpty else {
            throw VaultRepositoryError.validationError("Email must not be empty.")
        }

        return try await apiClient.fetchPublicKey(email: email)
    }
}
