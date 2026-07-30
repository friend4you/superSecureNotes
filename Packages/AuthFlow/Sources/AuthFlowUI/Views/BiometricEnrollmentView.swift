import AuthFlowProtocol
import SwiftUI

public struct BiometricEnrollmentView: View {
    @State private var password = ""
    private let viewModel: DefaultBiometricEnrollmentViewModel

    public init(viewModel: DefaultBiometricEnrollmentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(AuthFlowUILocalization.localized("bio.enrollment.message"))
                }

                Section {
                    SecureField(
                        AuthFlowUILocalization.localized("bio.enrollment.password"),
                        text: $password
                    )
                }

                Section {
                    Button(AuthFlowUILocalization.localized("bio.enrollment.enable")) {
                        Task {
                            try? await viewModel.enableBiometrics(password: password)
                        }
                    }

                    Button(AuthFlowUILocalization.localized("bio.enrollment.skip")) {
                        viewModel.skip()
                    }
                }
            }
            .navigationTitle(AuthFlowUILocalization.localized("bio.enrollment.title"))
        }
    }
}
