import AuthFlowDomainProtocol
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
    private let sessionPasswordCache: any SessionPasswordCaching

    public init(
        credentialStore: any CredentialStore,
        sessionPasswordCache: any SessionPasswordCaching
    ) {
        self.credentialStore = credentialStore
        self.sessionPasswordCache = sessionPasswordCache
        self.isBiometricsEnabled = credentialStore.bioEnabled()
    }

    public func enableBiometrics() async {
        if let cachedPassword = sessionPasswordCache.password() {
            do {
                try credentialStore.setBioEnabled(true)
                try credentialStore.savePassword(cachedPassword)
                isBiometricsEnabled = true
                requiresPasswordConfirmation = false
                password = ""
            } catch {
                requiresPasswordConfirmation = true
            }
            return
        }

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
