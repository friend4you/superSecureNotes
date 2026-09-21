import AuthFlowProtocol
import SwiftUI

public struct BiometricSettingsView: View {
    @Bindable private var viewModel: DefaultBiometricSettingsViewModel
    @State private var showDeleteConfirmation = false

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
                    Link(
                        String(localized: "bio.settings.privacyPolicy", bundle: .module),
                        destination: AuthLegalLinks.privacyPolicyURL
                    )
                    Link(
                        String(localized: "bio.settings.support", bundle: .module),
                        destination: AuthLegalLinks.supportEmailURL
                    )
                }

                if viewModel.isDeleteAccountFlowActive {
                    Section {
                        Text(String(localized: "bio.settings.deleteAccount.message", bundle: .module))
                            .foregroundStyle(.secondary)
                        SecureField(
                            String(localized: "bio.settings.deleteAccount.password", bundle: .module),
                            text: $viewModel.deleteAccountPassword
                        )
                        if let deleteAccountError = viewModel.deleteAccountError {
                            Text(AuthFlowErrorText.localized(deleteAccountError))
                                .foregroundStyle(.red)
                        }
                        Button(
                            String(localized: "bio.settings.deleteAccount.confirmButton", bundle: .module),
                            role: .destructive
                        ) {
                            Task {
                                await viewModel.deleteAccount()
                            }
                        }
                        .disabled(viewModel.isDeletingAccount)
                        Button(String(localized: "bio.settings.deleteAccount.cancel", bundle: .module)) {
                            viewModel.cancelDeleteAccount()
                        }
                    }
                }

                Section {
                    Button(String(localized: "bio.settings.deleteAccount", bundle: .module), role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(viewModel.isDeleteAccountFlowActive)

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
            .confirmationDialog(
                String(localized: "bio.settings.deleteAccount.confirm", bundle: .module),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    String(localized: "bio.settings.deleteAccount.confirmButton", bundle: .module),
                    role: .destructive
                ) {
                    viewModel.beginDeleteAccount()
                }
                Button(String(localized: "bio.settings.deleteAccount.cancel", bundle: .module), role: .cancel) {}
            }
        }
    }
}
