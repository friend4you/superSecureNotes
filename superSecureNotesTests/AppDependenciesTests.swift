import AuthFlowUI
import AuthRepository
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

    func testStubModeUsesInMemoryAuthAndFileVaultRepositories() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.authRepository is InMemoryAuthRepository)
        XCTAssertTrue(dependencies.vaultRepository is FileVaultRepository)
    }

    func testStubModeUsesRealCryptoAndVaultSession() {
        StubBackendConfiguration.testLaunchArguments = ["-UseStubBackend"]
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.vaultAuthenticator is SecureCryptoVaultAuthenticator)
        XCTAssertTrue(dependencies.vaultSession is VaultSession)
    }

    func testNetworkModeUsesNetworkRepositories() {
        StubBackendConfiguration.testLaunchArguments = []
        let dependencies = AppDependencies()

        XCTAssertTrue(dependencies.authRepository is NetworkAuthRepository)
        XCTAssertTrue(dependencies.vaultRepository is NetworkVaultRepository)
    }
}
