import AuthFlowDomainProtocol
import CredentialStoreProtocol
import Foundation
import NavigationProtocol
import Observation

@Observable
@MainActor
public final class DefaultBiometricSettingsViewModel: BiometricSettingsViewModel {
    public private(set) var isBiometricsEnabled: Bool
    public private(set) var requiresPasswordConfirmation = false
    public var password = ""
    public private(set) var isDeleteAccountFlowActive = false
    public private(set) var isDeletingAccount = false
    public var deleteAccountPassword = ""
    public private(set) var deleteAccountError: AuthFlowError?

    private let credentialStore: any CredentialStore
    private let sessionPasswordCache: any SessionPasswordCaching
    private let navigator: any Navigating
    private let deleteAccountUseCase: any DeleteAccountUseCase
    private let performLogout: () async -> Void

    public init(
        credentialStore: any CredentialStore,
        sessionPasswordCache: any SessionPasswordCaching,
        navigator: any Navigating,
        deleteAccountUseCase: any DeleteAccountUseCase,
        performLogout: @escaping () async -> Void
    ) {
        self.credentialStore = credentialStore
        self.sessionPasswordCache = sessionPasswordCache
        self.navigator = navigator
        self.deleteAccountUseCase = deleteAccountUseCase
        self.performLogout = performLogout
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

    public func beginDeleteAccount() {
        isDeleteAccountFlowActive = true
        deleteAccountPassword = ""
        deleteAccountError = nil
    }

    public func cancelDeleteAccount() {
        isDeleteAccountFlowActive = false
        deleteAccountPassword = ""
        deleteAccountError = nil
    }

    public func deleteAccount() async {
        guard !deleteAccountPassword.isEmpty else {
            deleteAccountError = .validationError(nil)
            return
        }

        isDeletingAccount = true
        deleteAccountError = nil
        defer { isDeletingAccount = false }

        do {
            try await deleteAccountUseCase.execute(password: deleteAccountPassword)
            isDeleteAccountFlowActive = false
            deleteAccountPassword = ""
        } catch let error as AuthFlowError {
            deleteAccountError = error
        } catch {
            deleteAccountError = .unknown
        }
    }

    public func logout() async {
        await performLogout()
    }

    public func dismiss() {
        navigator.dismissPresentation()
    }
}
