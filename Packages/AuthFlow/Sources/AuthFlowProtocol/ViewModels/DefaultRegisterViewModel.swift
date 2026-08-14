import AuthFlowDomain
import AuthFlowRoutes
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultRegisterViewModel: RegisterViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let registerUseCase: any RegisterUseCase
    private let navigator: any Navigating

    public init(
        registerUseCase: any RegisterUseCase,
        navigator: any Navigating
    ) {
        self.registerUseCase = registerUseCase
        self.navigator = navigator
    }

    public func register() async {
        state = .loading

        do {
            let result = try await registerUseCase.execute(email: email, password: password)
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
