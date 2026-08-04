import AuthFlowUI
import AuthRepository
import CredentialStore
import NetworkMonitoring
import NoteRepository
import VaultRepository
import XCTest

@testable import superSecureNotes

@MainActor
final class AppDependenciesTests: XCTestCase {
    func testUsesLocalhostAPIBaseURL() {
        XCTAssertEqual(AppDependencies.apiBaseURL.absoluteString, "http://localhost:8000/v1")
    }

    func testUsesNetworkAuthRepository() async {
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.authRepository is NetworkAuthRepository)
        await Task.yield()
    }

    func testUsesLocalRepositoriesAsSourceOfTruth() async {
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.vaultRepository is LocalVaultRepository)
        XCTAssertTrue(dependencies.noteRepository is LocalNoteRepository)
        XCTAssertTrue(dependencies.localVaultRepository === dependencies.vaultRepository as? LocalVaultRepository)
        XCTAssertTrue(dependencies.localNoteRepository === dependencies.noteRepository as? LocalNoteRepository)
        await Task.yield()
    }

    func testConstructsNetworkClientsAndSyncService() async {
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.networkVaultRepository is NetworkVaultRepository)
        XCTAssertTrue(dependencies.networkNoteRepository is NetworkNoteRepository)
        XCTAssertTrue(dependencies.noteSyncService is LocalFirstNoteSyncService)
        await Task.yield()
    }

    func testAppDependenciesProvidesSessionPersistenceServices() async {
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.credentialStore is KeychainCredentialStore)
        XCTAssertTrue(dependencies.biometricAuthenticator is LocalAuthenticationBiometricAuthenticator)
        XCTAssertTrue(dependencies.networkReachability is NWPathNetworkReachability)
        await Task.yield()
    }
}
