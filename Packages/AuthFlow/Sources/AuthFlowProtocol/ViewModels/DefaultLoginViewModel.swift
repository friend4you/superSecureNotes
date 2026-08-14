import AuthFlowDomain
import AuthFlowRoutes
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultLoginViewModel: LoginViewModel {
    public var email = ""
    public var password = ""
    public private(set) var state: AuthFormState = .idle

    private let loginUseCase: any LoginUseCase
    private let credentialStore: any CredentialStore
    private let navigator: any Navigating
    private let sessionExpiredNotifier: SessionExpiredNotifier
    private let pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring

    public init(
        loginUseCase: any LoginUseCase,
        credentialStore: any CredentialStore,
        navigator: any Navigating,
        sessionExpiredNotifier: SessionExpiredNotifier = SessionExpiredNotifier(),
        pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring
    ) {
        self.loginUseCase = loginUseCase
        self.credentialStore = credentialStore
        self.navigator = navigator
        self.sessionExpiredNotifier = sessionExpiredNotifier
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
    }

    public func onAppear() {
        if sessionExpiredNotifier.consumeSessionExpiredFlag() {
            state = .failure(.sessionExpired)
        }
    }

    public func registerTapped() {
        navigator.push(AuthRoute.register)
    }

    public func login() async {
        state = .loading
        let shouldPresentEnrollment = !credentialStore.hasLocalSetup
        if shouldPresentEnrollment {
            pendingBiometricEnrollmentStore.setPending(true)
        }

        do {
            let result = try await loginUseCase.execute(email: email, password: password)
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
