import AuthFlowProtocol
import SwiftUI

public struct LoginView: View {
    @Bindable private var viewModel: DefaultLoginViewModel

    public init(viewModel: DefaultLoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            credentialsSection
            errorSection
            actionsSection
        }
        .navigationTitle(String(localized: "login.title", bundle: .module))
        .onAppear {
            viewModel.onAppear()
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        Section {
            TextField(
                String(localized: "login.email", bundle: .module),
                text: $viewModel.email
            )
            .textContentType(.emailAddress)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            #endif

            SecureField(
                String(localized: "login.password", bundle: .module),
                text: $viewModel.password
            )
            .textContentType(.password)
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
            Button(String(localized: "login.submit", bundle: .module)) {
                Task {
                    await viewModel.login()
                }
            }
            .disabled(viewModel.state == .loading)

            Button(String(localized: "login.registerLink", bundle: .module)) {
                viewModel.registerTapped()
            }
        }
    }
}

#Preview {
    let deps = PreviewSupport.makeDependencies()
    return NavigationStack {
        LoginView(viewModel: deps.makeLoginViewModel())
    }
}
