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
                    Text(String(localized: "bio.enrollment.message", bundle: .module))
                }

                Section {
                    SecureField(
                        String(localized: "bio.enrollment.password", bundle: .module),
                        text: $password
                    )
                }

                Section {
                    Button(String(localized: "bio.enrollment.enable", bundle: .module)) {
                        Task {
                            try? await viewModel.enableBiometrics(password: password)
                        }
                    }

                    Button(String(localized: "bio.enrollment.skip", bundle: .module)) {
                        viewModel.skip()
                    }
                }
            }
            .navigationTitle(String(localized: "bio.enrollment.title", bundle: .module))
        }
    }
}
