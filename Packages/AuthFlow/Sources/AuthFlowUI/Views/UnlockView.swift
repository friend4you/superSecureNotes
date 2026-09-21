import AuthFlowProtocol
import SwiftUI

public struct UnlockView: View {
    @Bindable private var viewModel: DefaultUnlockViewModel

    public init(viewModel: DefaultUnlockViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            credentialsSection
            if showsLoadingIndicator {
                AuthLoadingSection()
            }
            errorSection
            actionsSection
        }
        .navigationTitle(String(localized: "unlock.title", bundle: .module))
        .onAppear {
            Task {
                await viewModel.onAppear()
            }
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        Section {
            Text(viewModel.email)
                .foregroundStyle(.secondary)

            if showsPasswordField {
                SecureField(
                    String(localized: "unlock.password", bundle: .module),
                    text: $viewModel.password
                )
                .textContentType(.password)
                .disabled(viewModel.state == .loading || viewModel.isLoggingOut)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if case .failure(let error) = viewModel.state {
            Section {
                Text(AuthFlowErrorText.localized(error))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            if showsPasswordField {
                Button(String(localized: "unlock.submit", bundle: .module)) {
                    Task {
                        await viewModel.unlockWithPassword()
                    }
                }
                .disabled(viewModel.state == .loading || viewModel.isLoggingOut)
            }

            if showsBiometricRetry {
                Button(String(localized: "unlock.useBiometrics", bundle: .module)) {
                    Task {
                        await viewModel.retryBiometrics()
                    }
                }
                .disabled(viewModel.state == .loading || viewModel.isLoggingOut)
            }

            Button(String(localized: "unlock.logout", bundle: .module), role: .destructive) {
                Task {
                    await viewModel.logout()
                }
            }
            .disabled(viewModel.state == .loading || viewModel.isLoggingOut)
        }
    }

    private var showsLoadingIndicator: Bool {
        viewModel.state == .loading
            || viewModel.state == .awaitingPresence
            || viewModel.isLoggingOut
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
