import AuthFlowProtocol
import SwiftUI

public struct UnlockView: View {
    @Bindable private var viewModel: DefaultUnlockViewModel

    public init(viewModel: DefaultUnlockViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                Text(viewModel.email)
                    .foregroundStyle(.secondary)

                if showsPasswordField {
                    SecureField(
                        AuthFlowUILocalization.localized("unlock.password"),
                        text: $viewModel.password
                    )
                    .textContentType(.password)
                }
            }

            if case .failure(let error) = viewModel.state {
                Section {
                    Text(AuthFlowErrorText.localized(error))
                        .foregroundStyle(.red)
                }
            }

            Section {
                if showsPasswordField {
                    Button(AuthFlowUILocalization.localized("unlock.submit")) {
                        Task {
                            await viewModel.unlockWithPassword()
                        }
                    }
                    .disabled(viewModel.state == .loading)
                }

                if showsBiometricRetry {
                    Button(AuthFlowUILocalization.localized("unlock.useBiometrics")) {
                        Task {
                            await viewModel.retryBiometrics()
                        }
                    }
                }

                Button(AuthFlowUILocalization.localized("unlock.logout"), role: .destructive) {
                    Task {
                        await viewModel.logout()
                    }
                }
                .disabled(viewModel.state == .loading)
            }
        }
        .navigationTitle(AuthFlowUILocalization.localized("unlock.title"))
        .onAppear {
            Task {
                await viewModel.onAppear()
            }
        }
    }

    private var showsPasswordField: Bool {
        switch viewModel.state {
        case .passwordEntry, .failure, .loading:
            return true
        case .idle, .awaitingPresence:
            return false
        }
    }

    private var showsBiometricRetry: Bool {
        switch viewModel.state {
        case .passwordEntry, .failure:
            return true
        case .idle, .awaitingPresence, .loading:
            return false
        }
    }
}
