import Foundation

@MainActor
public protocol BiometricEnrollmentViewModel: Observable {
    func enableBiometrics(password: String) async throws
    func skip()
}

@MainActor
public protocol BiometricSettingsViewModel: Observable {
    var isBiometricsEnabled: Bool { get }
    var requiresPasswordConfirmation: Bool { get }
    var password: String { get set }

    func enableBiometrics() async
    func disableBiometrics() async
}
