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
                String(localized: "bio.settings.toggle", bundle: .module),
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
                    String(localized: "bio.settings.password", bundle: .module),
                    text: $viewModel.password
                )
            }
        }
        .navigationTitle(String(localized: "bio.settings.title", bundle: .module))
    }
}
