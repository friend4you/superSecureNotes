import AuthFlowDomain
import AuthFlowDomainProtocol
import AuthFlowProtocol
import CryptoKit
import SecureCrypto
import VaultSessionProtocol
import XCTest

@MainActor
final class EstablishVaultSessionUseCaseTests: XCTestCase {
    func testStandardUnlockEstablishesSessionAndOpensIndex() async throws {
        let vaultAuthenticator = MockVaultAuthenticator()
        let vaultSession = MockVaultSession()
        let notesIndexStore = MockNotesIndexStore()
        let sessionKeys = VaultSessionKeys(
            udk: SymmetricKey(size: .bits256),
            identityPrivateKey: Data(repeating: 0x01, count: 32)
        )
        vaultAuthenticator.unlockOutcome = VaultUnlockOutcome(sessionKeys: sessionKeys)
        let useCase = AuthFlowTestSupport.makeEstablishVaultSessionUseCase(
            vaultAuthenticator: vaultAuthenticator,
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )

        try await useCase.execute(
            headerData: Data([0x01]),
            password: "secret",
            policy: .standardUnlock
        )

        XCTAssertEqual(vaultAuthenticator.unlockVaultCallCount, 1)
        let establishedKeys = await vaultSession.establishedKeys
        let openCallCount = await notesIndexStore.openCallCount
        let lastPassphrase = await notesIndexStore.lastPassphrase
        XCTAssertNotNil(establishedKeys)
        XCTAssertEqual(openCallCount, 1)
        XCTAssertEqual(lastPassphrase, deriveNotesDatabaseKey(from: sessionKeys.udk))
    }

    func testFirstLoginWithRemoteHeaderPullsCatalogsBeforeEstablish() async throws {
        let tracker = SequenceTracker()
        let noteSync = MockNoteSyncService()
        await noteSync.setOnPullRemoteNotesCatalog {
            tracker.record("pullNotes")
        }
        let vaultSession = MockVaultSession()
        await vaultSession.setOnEstablish {
            tracker.record("establish")
        }
        let useCase = AuthFlowTestSupport.makeEstablishVaultSessionUseCase(
            vaultSession: vaultSession,
            noteSync: noteSync
        )

        try await useCase.execute(
            headerData: Data([0x01]),
            password: "secret",
            policy: .firstLoginWithRemoteHeader
        )

        let pullSharedCount = await noteSync.pullRemoteSharedCatalogCallCount
        XCTAssertEqual(pullSharedCount, 1)
        XCTAssertEqual(tracker.recordedEvents, ["pullNotes", "establish"])
    }

    func testIndexOpenFailureClearsVaultSession() async throws {
        let vaultSession = MockVaultSession()
        let notesIndexStore = MockNotesIndexStore()
        await notesIndexStore.setOpenError(TestError.openFailed)
        let useCase = AuthFlowTestSupport.makeEstablishVaultSessionUseCase(
            vaultSession: vaultSession,
            notesIndexStore: notesIndexStore
        )

        do {
            try await useCase.execute(
                headerData: Data([0x01]),
                password: "secret",
                policy: .standardUnlock
            )
            XCTFail("Expected open to throw")
        } catch {
            let clearCallCount = await vaultSession.clearCallCount
            let establishedKeys = await vaultSession.establishedKeys
            XCTAssertEqual(clearCallCount, 1)
            XCTAssertNil(establishedKeys)
        }
    }
}

private enum TestError: Error {
    case openFailed
}

private final class SequenceTracker: @unchecked Sendable {
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

private extension MockNotesIndexStore {
    func setOpenError(_ error: Error) {
        openError = error
    }
}
