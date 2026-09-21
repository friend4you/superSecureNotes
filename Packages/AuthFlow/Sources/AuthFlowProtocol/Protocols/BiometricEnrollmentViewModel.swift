import AuthFlowDomainProtocol
import Foundation

@MainActor
public protocol BiometricEnrollmentViewModel: Observable {
    func enableBiometrics() async throws
    func skip()
}

@MainActor
public protocol BiometricSettingsViewModel: Observable {
    var isBiometricsEnabled: Bool { get }
    var requiresPasswordConfirmation: Bool { get }
    var password: String { get set }
    var isDeleteAccountFlowActive: Bool { get }
    var isDeletingAccount: Bool { get }
    var deleteAccountPassword: String { get set }
    var deleteAccountError: AuthFlowError? { get }

    func enableBiometrics() async
    func disableBiometrics() async
    func beginDeleteAccount()
    func cancelDeleteAccount()
    func deleteAccount() async
    func logout() async
    func dismiss()
}
