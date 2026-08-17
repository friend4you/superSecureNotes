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
        case .unlock:
            unlockView(deps: deps)
        case .settings:
            settingsView(deps: deps)
        case .biometricEnrollment:
            biometricEnrollmentView(deps: deps)
        }
    }

    public static func biometricEnrollmentView(deps: any AuthFlowDependencyProviding) -> BiometricEnrollmentView {
        BiometricEnrollmentView(viewModel: deps.makeBiometricEnrollmentViewModel())
    }

    public static func loginView(deps: any AuthFlowDependencyProviding) -> LoginView {
        LoginView(viewModel: deps.makeLoginViewModel())
    }

    public static func registerView(deps: any AuthFlowDependencyProviding) -> RegisterView {
        RegisterView(viewModel: deps.makeRegisterViewModel())
    }

    public static func unlockView(deps: any AuthFlowDependencyProviding) -> UnlockView {
        UnlockView(viewModel: deps.makeUnlockViewModel())
    }

    public static func settingsView(deps: any AuthFlowDependencyProviding) -> some View {
        BiometricSettingsView(viewModel: deps.makeBiometricSettingsViewModel())
            .presentationDetents([.medium, .large])
    }
}
