import AuthRepositoryProtocol
import Foundation
import Observation
import VaultRepositoryProtocol
import VaultSessionProtocol

@Observable
@MainActor
public final class DefaultRegisterViewModel: RegisterViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
    }

    public func register() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .failure(.validationError)
            return
        }

        state = .loading

        do {
            _ = try await authRepository.register(
                RegisterCredentials(email: email, password: password)
            )
            let creationOutcome = try vaultAuthenticator.createVault(password: password)
            try await vaultRepository.writeHeader(creationOutcome.headerData)
            let unlockOutcome = try vaultAuthenticator.unlockVault(
                headerData: creationOutcome.headerData,
                password: password
            )
            await vaultSession.establish(unlockOutcome.sessionKeys)
            state = .idle
        } catch let error as AuthRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch let error as VaultRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch {
            state = .failure(.networkError)
        }
    }
}
