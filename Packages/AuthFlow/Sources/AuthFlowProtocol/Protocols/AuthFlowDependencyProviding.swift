import AuthFlowRoutes
import CredentialStoreProtocol
import NavigationProtocol
import VaultRepositoryProtocol
import VaultSessionProtocol

@MainActor
public protocol AuthFlowDependencyProviding: AnyObject {
    func makeLoginViewModel() -> DefaultLoginViewModel
    func makeRegisterViewModel() -> DefaultRegisterViewModel
    func makeUnlockViewModel() -> DefaultUnlockViewModel
    func makeBiometricEnrollmentViewModel() -> DefaultBiometricEnrollmentViewModel
    func makeBiometricSettingsViewModel() -> DefaultBiometricSettingsViewModel
}
