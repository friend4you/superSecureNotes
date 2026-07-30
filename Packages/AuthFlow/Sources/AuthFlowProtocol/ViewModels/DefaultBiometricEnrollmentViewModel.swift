import CredentialStoreProtocol
import Foundation
import Observation

@Observable
@MainActor
public final class DefaultBiometricEnrollmentViewModel: BiometricEnrollmentViewModel {
    private let credentialStore: any CredentialStore
    private let onComplete: () -> Void

    public init(
        credentialStore: any CredentialStore,
        onComplete: @escaping () -> Void
    ) {
        self.credentialStore = credentialStore
        self.onComplete = onComplete
    }

    public func enableBiometrics(password: String) async throws {
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword(password)
        onComplete()
    }

    public func skip() {
        onComplete()
    }
}
