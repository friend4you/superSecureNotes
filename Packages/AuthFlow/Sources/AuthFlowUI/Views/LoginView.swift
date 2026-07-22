import AuthRepositoryProtocol
import AuthFlowProtocol
import SwiftUI

public struct LoginView: View {
    @Bindable private var viewModel: DefaultLoginViewModel
    private let makeRegisterViewModel: () -> DefaultRegisterViewModel

    public init(
        viewModel: DefaultLoginViewModel,
        makeRegisterViewModel: @escaping () -> DefaultRegisterViewModel
    ) {
        self.viewModel = viewModel
        self.makeRegisterViewModel = makeRegisterViewModel
    }

    public var body: some View {
        Form {
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

            if case .failure(let error) = viewModel.state {
                Section {
                    Text(AuthFlowErrorText.localized(error))
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(String(localized: "login.submit", bundle: .module)) {
                    Task {
                        await viewModel.login()
                    }
                }
                .disabled(viewModel.state == .loading)

                NavigationLink(
                    String(localized: "login.registerLink", bundle: .module)
                ) {
                    RegisterView(viewModel: makeRegisterViewModel())
                }
            }
        }
        .navigationTitle(String(localized: "login.title", bundle: .module))
    }
}

#Preview {
    NavigationStack {
        LoginView(
            viewModel: PreviewSupport.makeLoginViewModel(),
            makeRegisterViewModel: PreviewSupport.makeRegisterViewModel
        )
    }
}
