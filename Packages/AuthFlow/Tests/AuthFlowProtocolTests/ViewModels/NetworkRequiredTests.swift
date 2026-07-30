import AuthFlowProtocol
import XCTest

@MainActor
final class NetworkRequiredTests: XCTestCase {
    func testOfflineBlocksFirstLogin() async {
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .failure(.networkRequired))
    }

    func testOfflineBlocksFirstRegister() async {
        let viewModel = AuthFlowTestSupport.makeRegisterViewModel(
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.register()

        XCTAssertEqual(viewModel.state, .failure(.networkRequired))
    }

    func testOfflineDoesNotBlockUnlock() async throws {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh",
            vaultHeader: Data([0x01, 0x02])
        )
        let vaultSession = MockVaultSession()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            vaultSession: vaultSession,
            networkReachability: MockNetworkReachability(isOnline: false)
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        XCTAssertEqual(viewModel.state, .idle)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }
}
