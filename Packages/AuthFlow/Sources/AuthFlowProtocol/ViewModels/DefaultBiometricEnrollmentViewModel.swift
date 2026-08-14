import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultBiometricEnrollmentViewModel: BiometricEnrollmentViewModel {
    private let credentialStore: any CredentialStore
    private let navigator: any Navigating

    public init(
        credentialStore: any CredentialStore,
        navigator: any Navigating
    ) {
        self.credentialStore = credentialStore
        self.navigator = navigator
    }

    public func enableBiometrics(password: String) async throws {
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword(password)
        navigator.dismissPresentation()
    }

    public func skip() {
        navigator.dismissPresentation()
    }
}
