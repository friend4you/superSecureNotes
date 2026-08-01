import Foundation

@testable import VaultRepository

enum VaultTestSupport {
    static func makeAPIClient(
        tokenProvider: MockTokenProvider = MockTokenProvider(),
        session: URLSession = .stubbed()
    ) -> VaultAPIClient {
        VaultAPIClient(
            baseURL: VaultFixtures.baseURL,
            tokenProvider: tokenProvider,
            session: session
        )
    }

    static func makeRepository(
        tokenProvider: MockTokenProvider = MockTokenProvider(),
        session: URLSession = .stubbed()
    ) -> NetworkVaultRepository {
        NetworkVaultRepository(apiClient: makeAPIClient(
            tokenProvider: tokenProvider,
            session: session
        ))
    }
}
