import AuthFlowRoutes
import AuthRepositoryProtocol
import CredentialStoreProtocol
import NavigationProtocol
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
public protocol AuthFlowDependencyProviding: AnyObject {
    func makeLoginViewModel() -> DefaultLoginViewModel
    func makeRegisterViewModel() -> DefaultRegisterViewModel
    func makeUnlockViewModel() -> DefaultUnlockViewModel
    func makeBiometricEnrollmentViewModel(onComplete: @escaping () -> Void) -> DefaultBiometricEnrollmentViewModel
    func makeBiometricSettingsViewModel() -> DefaultBiometricSettingsViewModel
}
