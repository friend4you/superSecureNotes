import AuthFlowProtocol
import AuthRepositoryProtocol
import XCTest

@MainActor
final class DefaultUnlockViewModelFlushSyncTests: XCTestCase {
    func testOnlineUnlockFlushesPendingSync() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let noteSync = MockNoteSyncService()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            vaultSession: MockVaultSession(),
            networkReachability: MockNetworkReachability(isOnline: true),
            noteSync: noteSync
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let flushCallCount = await noteSync.flushCallCount
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(flushCallCount, 1)
    }

    func testOfflineUnlockSkipsFlush() async throws {
        let credentialStore = try makeConfiguredCredentialStore()
        let noteSync = MockNoteSyncService()

        let viewModel = AuthFlowTestSupport.makeUnlockViewModel(
            credentialStore: credentialStore,
            vaultSession: MockVaultSession(),
            networkReachability: MockNetworkReachability(isOnline: false),
            noteSync: noteSync
        )
        viewModel.password = "secret"

        await viewModel.unlockWithPassword()

        let flushCallCount = await noteSync.flushCallCount
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(flushCallCount, 0)
    }

    private func makeConfiguredCredentialStore() throws -> MockCredentialStore {
        let credentialStore = MockCredentialStore()
        try credentialStore.saveSetup(
            email: "user@example.com",
            refreshToken: "refresh-token",
            vaultHeader: Data([0x01, 0x02])
        )
        return credentialStore
    }
}
