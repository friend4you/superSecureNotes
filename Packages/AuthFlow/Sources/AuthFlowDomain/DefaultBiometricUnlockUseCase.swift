import AuthFlowDomainProtocol
import CredentialStoreProtocol

@MainActor
public final class DefaultBiometricUnlockUseCase: BiometricUnlockUseCase {
    private let credentialStore: any CredentialStore
    private let biometricAuthenticator: any BiometricAuthenticator

    public init(
        credentialStore: any CredentialStore,
        biometricAuthenticator: any BiometricAuthenticator
    ) {
        self.credentialStore = credentialStore
        self.biometricAuthenticator = biometricAuthenticator
    }

    public func execute() async -> BiometricUnlockResult {
        guard credentialStore.bioEnabled(), biometricAuthenticator.canEvaluateBiometrics() else {
            return .passwordEntryRequired
        }

        let result = await biometricAuthenticator.authenticate(
            reason: "Unlock your vault"
        )

        switch result {
        case .success:
            do {
                let password = try credentialStore.loadPasswordWithBiometrics()
                return .success(password: password)
            } catch {
                return .passwordEntryRequired
            }
        case .cancelled, .failed, .unavailable:
            return .passwordEntryRequired
        }
    }
}
