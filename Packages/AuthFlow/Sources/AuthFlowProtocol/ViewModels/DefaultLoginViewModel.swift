import AuthRepositoryProtocol
import Foundation
import Observation
import VaultRepositoryProtocol
import VaultSessionProtocol

@Observable
@MainActor
public final class DefaultLoginViewModel: LoginViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let authRepository: any AuthRepository
    private let vaultRepository: any VaultRepository
    private let vaultAuthenticator: any VaultAuthenticator
    private let vaultSession: any VaultSessionProtocol
    private let navigator: any LoginNavigating

    public init(
        authRepository: any AuthRepository,
        vaultRepository: any VaultRepository,
        vaultAuthenticator: any VaultAuthenticator,
        vaultSession: any VaultSessionProtocol,
        navigator: any LoginNavigating
    ) {
        self.authRepository = authRepository
        self.vaultRepository = vaultRepository
        self.vaultAuthenticator = vaultAuthenticator
        self.vaultSession = vaultSession
        self.navigator = navigator
    }

    public func registerTapped() {
        navigator.showRegister()
    }

    public func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .failure(.validationError)
            return
        }

        state = .loading

        do {
            _ = try await authRepository.login(
                LoginCredentials(email: email, password: password)
            )
            let headerData = try await vaultRepository.readHeader()
            let unlockOutcome = try vaultAuthenticator.unlockVault(
                headerData: headerData,
                password: password
            )
            await vaultSession.establish(unlockOutcome.sessionKeys)
            state = .idle
        } catch let error as AuthRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch let error as VaultRepositoryError {
            state = .failure(AuthFlowErrorMapper.map(error))
        } catch {
            state = .failure(.vaultUnlockFailed)
        }
    }
}
