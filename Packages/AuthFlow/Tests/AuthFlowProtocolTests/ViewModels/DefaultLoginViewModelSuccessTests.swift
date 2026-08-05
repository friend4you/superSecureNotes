import AuthFlowProtocol
import XCTest

@MainActor
final class DefaultLoginViewModelSuccessTests: XCTestCase {
    func testLoginSucceedsAndEstablishesVaultSession() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        let loginCallCount = await authRepository.loginCallCount
        let readHeaderCallCount = await vaultRepository.readHeaderCallCount
        XCTAssertEqual(loginCallCount, 1)
        XCTAssertEqual(readHeaderCallCount, 1)
        XCTAssertEqual(authenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        XCTAssertNotNil(establishedKeys)
    }

    func testLoginPullsVaultHeaderWhenLocalMissing() async {
        let authRepository = MockAuthRepository()
        let vaultRepository = MockVaultRepository()
        let authenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let noteSync = MockNoteSyncService()
        await noteSync.setLocalVaultHeaderExists(false)
        await noteSync.setPullVaultHeaderResult(Data([0x0B]))
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            authRepository: authRepository,
            vaultRepository: vaultRepository,
            vaultAuthenticator: authenticator,
            vaultSession: vaultSession,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        let readHeaderCallCount = await vaultRepository.readHeaderCallCount
        let pullVaultHeaderCallCount = await noteSync.pullVaultHeaderCallCount
        let pullNotesCallCount = await noteSync.pullRemoteNotesCatalogCallCount
        XCTAssertEqual(readHeaderCallCount, 0)
        XCTAssertEqual(pullVaultHeaderCallCount, 1)
        XCTAssertEqual(pullNotesCallCount, 1)
        XCTAssertEqual(authenticator.lastUnlockHeaderData, Data([0x0B]))
    }

    func testLoginPullsNotesBeforeEstablishingSession() async {
        let tracker = LoginSequenceTracker()
        let noteSync = MockNoteSyncService()
        await noteSync.setLocalVaultHeaderExists(false)
        await noteSync.setPullVaultHeaderResult(Data([0x0B]))
        await noteSync.setOnPullRemoteNotesCatalog {
            tracker.record("pull")
        }
        let vaultSession = MockVaultSession()
        await vaultSession.setOnEstablish {
            tracker.record("establish")
        }
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            vaultSession: vaultSession,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(tracker.recordedEvents, ["pull", "establish"])
    }

    func testLoginReadsLocalHeaderWhenFileExists() async {
        let vaultRepository = MockVaultRepository()
        let noteSync = MockNoteSyncService()
        let viewModel = AuthFlowTestSupport.makeLoginViewModel(
            vaultRepository: vaultRepository,
            noteSync: noteSync
        )
        viewModel.email = "user@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        XCTAssertEqual(viewModel.state, .idle)
        let readHeaderCallCount = await vaultRepository.readHeaderCallCount
        let pullNotesCallCount = await noteSync.pullRemoteNotesCatalogCallCount
        XCTAssertEqual(readHeaderCallCount, 1)
        XCTAssertEqual(pullNotesCallCount, 0)
    }
}

private final class LoginSequenceTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    func record(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    var recordedEvents: [String] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

private extension MockNoteSyncService {
    func setOnPullRemoteNotesCatalog(_ handler: @escaping @Sendable () -> Void) {
        onPullRemoteNotesCatalog = handler
    }
}

private extension MockVaultSession {
    func setOnEstablish(_ handler: @escaping @Sendable () -> Void) {
        onEstablish = handler
    }
}

private extension MockNoteSyncService {
    func setLocalVaultHeaderExists(_ exists: Bool) {
        localVaultHeaderExists = exists
    }

    func setPullVaultHeaderResult(_ data: Data) {
        pullVaultHeaderResult = data
    }
}
