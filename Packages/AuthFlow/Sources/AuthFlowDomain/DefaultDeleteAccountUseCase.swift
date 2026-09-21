import AuthFlowDomainProtocol
import AuthRepositoryProtocol
import Foundation

@MainActor
public final class DefaultDeleteAccountUseCase: DeleteAccountUseCase {
    private let authRepository: any AuthRepository
    private let performFullReset: () async -> Void

    public init(
        authRepository: any AuthRepository,
        performFullReset: @escaping () async -> Void
    ) {
        self.authRepository = authRepository
        self.performFullReset = performFullReset
    }

    public func execute(password: String) async throws {
        do {
            try await authRepository.deleteAccount(password: password)
        } catch let error as AuthRepositoryError {
            throw AuthFlowErrorMapper.map(error)
        }
        await performFullReset()
    }
}
