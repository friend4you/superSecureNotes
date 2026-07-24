import AuthFlowProtocol
import AuthFlowRoutes
import SwiftUI

@MainActor
enum AuthNavigation {
    @ViewBuilder
    static func view(for route: AuthRoute, deps: any AuthFlowDependencyProviding) -> some View {
        switch route {
        case .login:
            loginView(deps: deps)
        case .register:
            registerView(deps: deps)
        }
    }

    static func loginView(deps: any AuthFlowDependencyProviding) -> LoginView {
        LoginView(
            viewModel: deps.makeLoginViewModel(),
            makeRegisterViewModel: { deps.makeRegisterViewModel() }
        )
    }

    static func registerView(deps: any AuthFlowDependencyProviding) -> RegisterView {
        RegisterView(viewModel: deps.makeRegisterViewModel())
    }
}
