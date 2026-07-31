import AuthFlowUI
import AuthRepository
import CredentialStore
import NetworkMonitoring
import NoteRepository
import VaultRepository
import VaultSession
import XCTest

@testable import superSecureNotes

@MainActor
final class AppDependenciesTests: XCTestCase {
    override func tearDown() {
        StubBackendConfiguration.testLaunchArguments = nil
        super.tearDown()
    }

    func testStubModeUsesInMemoryAuthAndLocalRepositories() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.authRepository is InMemoryAuthRepository)
        XCTAssertTrue(dependencies.vaultRepository is LocalVaultRepository)
        XCTAssertTrue(dependencies.noteRepository is LocalNoteRepository)
    }

    func testStubModeUsesRealCryptoAndVaultSession() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.vaultAuthenticator is SecureCryptoVaultAuthenticator)
        XCTAssertTrue(dependencies.vaultSession is VaultSession)
    }

    func testNetworkModeUsesNetworkAuthWithLocalRepositories() {
        StubBackendConfiguration.testLaunchArguments = []
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.authRepository is NetworkAuthRepository)
        XCTAssertTrue(dependencies.vaultRepository is LocalVaultRepository)
        XCTAssertTrue(dependencies.noteRepository is LocalNoteRepository)
    }

    func testAppDependenciesProvidesSessionPersistenceServices() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.credentialStore is KeychainCredentialStore)
        XCTAssertTrue(dependencies.biometricAuthenticator is LocalAuthenticationBiometricAuthenticator)
        XCTAssertTrue(dependencies.networkReachability is NWPathNetworkReachability)
    }
}
