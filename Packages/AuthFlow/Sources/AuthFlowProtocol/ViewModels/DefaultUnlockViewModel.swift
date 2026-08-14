import AuthFlowDomain
import AuthFlowRoutes
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultUnlockViewModel: UnlockViewModel {
    public private(set) var email: String
    public var password = ""
    public private(set) var state: UnlockFormState = .awaitingPresence

    private let unlockUseCase: any UnlockUseCase
    private let biometricUnlockUseCase: any BiometricUnlockUseCase
    private let navigator: any Navigating
    private let pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring
    private let performLogout: () async -> Void

    public init(
        email: String,
        unlockUseCase: any UnlockUseCase,
        biometricUnlockUseCase: any BiometricUnlockUseCase,
        navigator: any Navigating,
        pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring,
        performLogout: @escaping () async -> Void = {}
    ) {
        self.email = email
        self.unlockUseCase = unlockUseCase
        self.biometricUnlockUseCase = biometricUnlockUseCase
        self.navigator = navigator
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
        self.performLogout = performLogout
    }

    public func onAppear() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func retryBiometrics() async {
        await attemptBiometricUnlockIfEnabled()
    }

    public func logout() async {
        await performLogout()
    }

    public func unlockWithPassword() async {
        guard !password.isEmpty else {
            state = .failure(.validationError(nil))
            return
        }
        await performUnlock(using: password)
    }

    private func attemptBiometricUnlockIfEnabled() async {
        state = .awaitingPresence
        let result = await biometricUnlockUseCase.execute()

        switch result {
        case let .success(unlockPassword):
            await performUnlock(using: unlockPassword)
        case .passwordEntryRequired:
            state = .passwordEntry
        }
    }

    private func performUnlock(using unlockPassword: String) async {
        state = .loading

        do {
            try await unlockUseCase.execute(password: unlockPassword, email: email)
            if pendingBiometricEnrollmentStore.isPending {
                navigator.present(AuthRoute.biometricEnrollment, style: .sheet)
            }
            state = .idle
            password = ""
        } catch let error as AuthFlowError {
            state = .failure(error)
        } catch {
            state = .failure(.vaultUnlockFailed)
        }
    }
}
