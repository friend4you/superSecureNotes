import AuthFlowProtocol
import SwiftUI

public struct BiometricSettingsView: View {
    @Bindable private var viewModel: DefaultBiometricSettingsViewModel

    public init(viewModel: DefaultBiometricSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
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

                Section {
                    Button(String(localized: "bio.settings.logout", bundle: .module), role: .destructive) {
                        Task {
                            await viewModel.logout()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "bio.settings.title", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "bio.settings.done", bundle: .module)) {
                        viewModel.dismiss()
                    }
                }
            }
        }
    }
}
