import AuthFlowProtocol
import SwiftUI

public struct BiometricSettingsView: View {
    @Bindable private var viewModel: DefaultBiometricSettingsViewModel

    public init(viewModel: DefaultBiometricSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Toggle(
                AuthFlowUILocalization.localized("bio.settings.toggle"),
                isOn: Binding(
                    get: { viewModel.isBiometricsEnabled },
                    set: { isEnabled in
                        Task {
                            if isEnabled {
                                await viewModel.enableBiometrics()
                            } else {
                                await viewModel.disableBiometrics()
                            }
                        }
                    }
                )
            )

            if viewModel.requiresPasswordConfirmation {
                SecureField(
                    AuthFlowUILocalization.localized("bio.settings.password"),
                    text: $viewModel.password
                )
            }
        }
        .navigationTitle(AuthFlowUILocalization.localized("bio.settings.title"))
    }
}
