import AuthRepositoryProtocol
import Foundation
import VaultRepositoryProtocol

public struct AuthRepositoryAccessTokenProvider: AccessTokenProviding {
    private let repository: any AuthRepository

    public init(repository: any AuthRepository) {
        self.repository = repository
    }

    public func accessToken() async throws -> String {
        guard let session = await repository.currentSession else {
            throw VaultRepositoryError.notAuthenticated
        }
        return session.accessToken
    }
}
