import AuthFlowProtocol
import AuthFlowRoutes
import SwiftUI

@MainActor
public enum AuthNavigation {
    @ViewBuilder
    public static func view(
        for route: AuthRoute,
        deps: any AuthFlowDependencyProviding
    ) -> some View {
        switch route {
        case .login:
            loginView(deps: deps)
        case .register:
            registerView(deps: deps)
        }
    }

    public static func loginView(deps: any AuthFlowDependencyProviding) -> LoginView {
        LoginView(viewModel: deps.makeLoginViewModel())
    }

    public static func registerView(deps: any AuthFlowDependencyProviding) -> RegisterView {
        RegisterView(viewModel: deps.makeRegisterViewModel())
    }
}
