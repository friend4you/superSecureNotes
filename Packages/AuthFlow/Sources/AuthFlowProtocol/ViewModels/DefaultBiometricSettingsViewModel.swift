import CredentialStoreProtocol
import Foundation
import Observation

@Observable
@MainActor
public final class DefaultBiometricSettingsViewModel: BiometricSettingsViewModel {
    public private(set) var isBiometricsEnabled: Bool
    public private(set) var requiresPasswordConfirmation = false
    public var password = ""

    private let credentialStore: any CredentialStore

    public init(credentialStore: any CredentialStore) {
        self.credentialStore = credentialStore
        self.isBiometricsEnabled = credentialStore.bioEnabled()
    }

    public func enableBiometrics() async {
        guard !password.isEmpty else {
            requiresPasswordConfirmation = true
            return
        }

        do {
            try credentialStore.setBioEnabled(true)
            try credentialStore.savePassword(password)
            isBiometricsEnabled = true
            requiresPasswordConfirmation = false
            password = ""
        } catch {
            requiresPasswordConfirmation = true
        }
    }

    public func disableBiometrics() async {
        do {
            try credentialStore.setBioEnabled(false)
            isBiometricsEnabled = false
            password = ""
            requiresPasswordConfirmation = false
        } catch {
            requiresPasswordConfirmation = false
        }
    }
}
