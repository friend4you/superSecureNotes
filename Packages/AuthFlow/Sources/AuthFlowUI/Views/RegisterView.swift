import AuthFlowProtocol
import SwiftUI

public struct RegisterView: View {
    @Bindable private var viewModel: DefaultRegisterViewModel

    public init(viewModel: DefaultRegisterViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "register.email", bundle: .module),
                    text: $viewModel.email
                )
                .textContentType(.emailAddress)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif

                SecureField(
                    String(localized: "register.password", bundle: .module),
                    text: $viewModel.password
                )
                .textContentType(.newPassword)
            }

            if case .failure(let error) = viewModel.state {
                Section {
                    Text(AuthFlowErrorText.localized(error))
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(String(localized: "register.submit", bundle: .module)) {
                    Task {
                        await viewModel.register()
                    }
                }
                .disabled(viewModel.state == .loading)
            }
        }
        .navigationTitle(String(localized: "register.title", bundle: .module))
    }
}

#Preview {
    NavigationStack {
        RegisterView(viewModel: PreviewSupport.makeRegisterViewModel())
    }
}
