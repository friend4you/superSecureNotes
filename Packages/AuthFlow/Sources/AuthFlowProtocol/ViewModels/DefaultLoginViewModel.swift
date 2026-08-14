import AuthFlowDomain
import AuthFlowRoutes
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultLoginViewModel: LoginViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let loginUseCase: any LoginUseCase
    private let navigator: any Navigating
    private let sessionExpiredNotifier: SessionExpiredNotifier

    public init(
        loginUseCase: any LoginUseCase,
        navigator: any Navigating,
        sessionExpiredNotifier: SessionExpiredNotifier = SessionExpiredNotifier()
    ) {
        self.loginUseCase = loginUseCase
        self.navigator = navigator
        self.sessionExpiredNotifier = sessionExpiredNotifier
    }

    public func onAppear() {
        if sessionExpiredNotifier.consumeSessionExpiredFlag() {
            state = .failure(.sessionExpired)
        }
    }

    public func registerTapped() {
        navigator.push(AuthRoute.register)
    }

    public func login() async {
        state = .loading

        do {
            let result = try await loginUseCase.execute(email: email, password: password)
            if result.wasFirstSetup {
                navigator.present(AuthRoute.biometricEnrollment, style: .sheet)
            }
            state = .idle
        } catch let error as AuthFlowError {
            state = .failure(error)
        } catch {
            state = .failure(.unknown)
        }
    }
}
