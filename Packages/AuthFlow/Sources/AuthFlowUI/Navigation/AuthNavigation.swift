import AuthFlowProtocol
import AuthFlowRoutes
import SwiftUI

@MainActor
enum AuthNavigation {
    @ViewBuilder
    static func view(
        for route: AuthRoute,
        deps: any AuthFlowDependencyProviding,
        navigator: any LoginNavigating
    ) -> some View {
        switch route {
        case .login:
            loginView(deps: deps, navigator: navigator)
        case .register:
            registerView(deps: deps)
        }
    }

    static func loginView(
        deps: any AuthFlowDependencyProviding,
        navigator: any LoginNavigating
    ) -> LoginView {
        LoginView(viewModel: deps.makeLoginViewModel(navigator: navigator))
    }

    static func registerView(deps: any AuthFlowDependencyProviding) -> RegisterView {
        RegisterView(viewModel: deps.makeRegisterViewModel())
    }
}
