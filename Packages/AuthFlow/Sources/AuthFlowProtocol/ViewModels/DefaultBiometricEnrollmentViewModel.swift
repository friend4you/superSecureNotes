import AuthFlowDomainProtocol
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultBiometricEnrollmentViewModel: BiometricEnrollmentViewModel {
    private let credentialStore: any CredentialStore
    private let sessionPasswordCache: any SessionPasswordCaching
    private let pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring
    private let navigator: any Navigating
    private let onEnrollmentCompleted: () -> Void

    public init(
        credentialStore: any CredentialStore,
        sessionPasswordCache: any SessionPasswordCaching,
        pendingBiometricEnrollmentStore: any PendingBiometricEnrollmentStoring,
        navigator: any Navigating,
        onEnrollmentCompleted: @escaping () -> Void = {}
    ) {
        self.credentialStore = credentialStore
        self.sessionPasswordCache = sessionPasswordCache
        self.pendingBiometricEnrollmentStore = pendingBiometricEnrollmentStore
        self.navigator = navigator
        self.onEnrollmentCompleted = onEnrollmentCompleted
    }

    public func enableBiometrics() async throws {
        guard let password = sessionPasswordCache.password() else {
            throw BiometricEnrollmentError.passwordUnavailable
        }
        try credentialStore.setBioEnabled(true)
        try credentialStore.savePassword(password)
        completeEnrollment()
    }

    public func skip() {
        completeEnrollment()
    }

    private func completeEnrollment() {
        pendingBiometricEnrollmentStore.setPending(false)
        navigator.dismissPresentation()
        onEnrollmentCompleted()
    }
}

public enum BiometricEnrollmentError: Error {
    case passwordUnavailable
}
