import CredentialStoreProtocol
import Foundation

public enum InstallMarker {
    public static let userDefaultsKey = "com.superSecureNotes.installMarker"

    /// Clears orphaned Keychain credentials when UserDefaults was wiped (e.g. app reinstall)
    /// but Keychain items survived. Records the install marker on first launch after wipe.
    /// When local app data still exists, only records the marker (app upgrade path).
    public static func reconcileOrphanedCredentialsIfNeeded(
        credentialStore: any CredentialStore,
        pendingBiometricEnrollmentStore: (any PendingBiometricEnrollmentStoring)? = nil,
        defaults: UserDefaults = .standard,
        key: String = userDefaultsKey,
        localAppDataRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        guard !defaults.bool(forKey: key) else { return }
        defer { defaults.set(true, forKey: key) }

        guard credentialStore.hasLocalSetup else { return }

        let appDataRoot = localAppDataRootURL ?? defaultLocalAppDataRoot(fileManager: fileManager)
        if fileManager.fileExists(atPath: appDataRoot.path) {
            return
        }

        try? credentialStore.clearAll()
        pendingBiometricEnrollmentStore?.setPending(false)
    }

    private static func defaultLocalAppDataRoot(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("superSecureNotes", isDirectory: true)
    }
}
