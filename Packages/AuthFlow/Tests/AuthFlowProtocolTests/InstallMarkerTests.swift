import AuthFlowProtocol
import XCTest

final class InstallMarkerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.superSecureNotes.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchSetsMarkerWithoutClearingEmptyCredentials() {
        let credentialStore = MockCredentialStore()

        InstallMarker.reconcileOrphanedCredentialsIfNeeded(
            credentialStore: credentialStore,
            defaults: defaults
        )

        XCTAssertTrue(defaults.bool(forKey: InstallMarker.userDefaultsKey))
        XCTAssertFalse(credentialStore.hasLocalSetup)
    }

    func testReinstallWithOrphanedKeychainClearsCredentialsAndSetsMarker() throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        let pendingStore = MockPendingBiometricEnrollmentStore()
        pendingStore.setPending(true)
        let missingLocalDataRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        InstallMarker.reconcileOrphanedCredentialsIfNeeded(
            credentialStore: credentialStore,
            pendingBiometricEnrollmentStore: pendingStore,
            defaults: defaults,
            localAppDataRootURL: missingLocalDataRoot
        )

        XCTAssertTrue(defaults.bool(forKey: InstallMarker.userDefaultsKey))
        XCTAssertFalse(credentialStore.hasLocalSetup)
        XCTAssertFalse(pendingStore.isPending)
    }

    func testSubsequentLaunchDoesNotClearCredentials() throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        defaults.set(true, forKey: InstallMarker.userDefaultsKey)

        InstallMarker.reconcileOrphanedCredentialsIfNeeded(
            credentialStore: credentialStore,
            defaults: defaults
        )

        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), "user@example.com")
    }

    func testUpgradeWithExistingLocalDataPreservesCredentials() throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01])
        )
        let localDataRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: localDataRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: localDataRoot) }

        InstallMarker.reconcileOrphanedCredentialsIfNeeded(
            credentialStore: credentialStore,
            defaults: defaults,
            localAppDataRootURL: localDataRoot
        )

        XCTAssertTrue(defaults.bool(forKey: InstallMarker.userDefaultsKey))
        XCTAssertTrue(credentialStore.hasLocalSetup)
        XCTAssertEqual(credentialStore.email(), "user@example.com")
    }
}
