import Foundation
import VaultRepositoryProtocol

public actor NetworkVaultRepository: VaultRepository {
    private let apiClient: VaultAPIClient
    private let tokenProvider: any AccessTokenProviding

    public init(
        baseURL: URL,
        tokenProvider: any AccessTokenProviding,
        session: URLSession = .shared
    ) {
        self.apiClient = VaultAPIClient(baseURL: baseURL, session: session)
        self.tokenProvider = tokenProvider
    }

    init(apiClient: VaultAPIClient, tokenProvider: any AccessTokenProviding) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    public func readHeader() async throws -> Data {
        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.readHeader(accessToken: accessToken)
    }

    public func writeHeader(_ header: Data) async throws {
        guard !header.isEmpty else {
            throw VaultRepositoryError.validationError("Vault header must not be empty.")
        }

        let accessToken = try await tokenProvider.accessToken()
        try await apiClient.writeHeader(header, accessToken: accessToken)
    }

    public func fetchPublicKey(userID: String) async throws -> Data {
        guard !userID.isEmpty else {
            throw VaultRepositoryError.validationError("User ID must not be empty.")
        }

        let accessToken = try await tokenProvider.accessToken()
        return try await apiClient.fetchPublicKey(userID: userID, accessToken: accessToken)
    }
}
