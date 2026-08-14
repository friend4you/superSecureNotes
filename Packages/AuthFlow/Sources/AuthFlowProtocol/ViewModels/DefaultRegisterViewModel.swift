import AuthFlowDomain
import AuthFlowRoutes
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultRegisterViewModel: RegisterViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let registerUseCase: any RegisterUseCase
    private let credentialStore: any CredentialStore
    private let navigator: any Navigating
    private let pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring

    public init(
        registerUseCase: any RegisterUseCase,
        credentialStore: any CredentialStore,
        navigator: any Navigating,
        pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring
    ) {
        self.registerUseCase = registerUseCase
        self.credentialStore = credentialStore
        self.navigator = navigator
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
    }

    public func register() async {
        state = .loading
        let shouldPresentEnrollment = !credentialStore.hasLocalSetup
        if shouldPresentEnrollment {
            pendingBiometricEnrollmentStore.setPending(true)
        }

        do {
            let result = try await registerUseCase.execute(email: email, password: password)
            if result.wasFirstSetup {
                navigator.present(AuthRoute.biometricEnrollment, style: .sheet)
            } else if shouldPresentEnrollment {
                pendingBiometricEnrollmentStore.setPending(false)
            }
            state = .idle
        } catch let error as AuthFlowError {
            if shouldPresentEnrollment {
                pendingBiometricEnrollmentStore.setPending(false)
            }
            state = .failure(error)
        } catch {
            if shouldPresentEnrollment {
                pendingBiometricEnrollmentStore.setPending(false)
            }
            state = .failure(.unknown)
        }
    }
}
