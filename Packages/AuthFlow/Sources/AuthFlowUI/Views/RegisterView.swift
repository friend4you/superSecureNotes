import AuthFlowProtocol
import SwiftUI

public struct RegisterView: View {
    @Bindable private var viewModel: DefaultRegisterViewModel

    public init(viewModel: DefaultRegisterViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            credentialsSection
            if viewModel.state == .loading {
                AuthLoadingSection()
            }
            privacySection
            errorSection
            actionsSection
        }
        .navigationTitle(String(localized: "register.title", bundle: .module))
    }

    @ViewBuilder
    private var credentialsSection: some View {
        Section {
            TextField(
                String(localized: "register.email", bundle: .module),
                text: $viewModel.email
            )
            .textContentType(.emailAddress)
            .disabled(viewModel.state == .loading)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            #endif

            SecureField(
                String(localized: "register.password", bundle: .module),
                text: $viewModel.password
            )
            .textContentType(.newPassword)
            .disabled(viewModel.state == .loading)
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            Link(
                String(localized: "register.privacyPolicy", bundle: .module),
                destination: AuthLegalLinks.privacyPolicyURL
            )
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
            Button(String(localized: "register.submit", bundle: .module)) {
                Task {
                    await viewModel.register()
                }
            }
            .disabled(viewModel.state == .loading)
        }
    }
}

#Preview {
    let deps = PreviewSupport.makeDependencies()
    return NavigationStack {
        RegisterView(viewModel: deps.makeRegisterViewModel())
    }
}
