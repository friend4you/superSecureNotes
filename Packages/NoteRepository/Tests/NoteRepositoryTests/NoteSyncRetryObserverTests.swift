import NetworkProtocol
import NoteRepositoryProtocol
import XCTest

@testable import NoteRepository

final class NoteSyncRetryObserverTests: XCTestCase {
    func testFlushesWhenReachabilityTransitionsToOnline() async {
        let reachability = ControllableNetworkReachability(isOnline: false)
        let noteSync = MockNoteSyncService()
        let observation = NoteSyncRetryObserver.start(
            reachability: reachability,
            noteSync: noteSync
        )
        defer { observation.cancel() }

        await Task.yield()
        reachability.goOnline()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let flushCallCount = await noteSync.flushCallCount
        XCTAssertEqual(flushCallCount, 1)
    }

    func testDoesNotFlushWhenAlreadyOnline() async {
        let reachability = ControllableNetworkReachability(isOnline: true)
        let noteSync = MockNoteSyncService()
        let observation = NoteSyncRetryObserver.start(
            reachability: reachability,
            noteSync: noteSync
        )
        defer { observation.cancel() }

        reachability.goOnline()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let flushCallCount = await noteSync.flushCallCount
        XCTAssertEqual(flushCallCount, 0)
    }
}

private final class ControllableNetworkReachability: NetworkReachability, @unchecked Sendable {
    private let lock = NSLock()
    private var online: Bool
    private var continuation: AsyncStream<Bool>.Continuation?

    init(isOnline: Bool) {
        online = isOnline
    }

    var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return online
    }

    var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            lock.lock()
            self.continuation = continuation
            let current = online
            lock.unlock()
            continuation.yield(current)
        }
    }

    func goOnline() {
        lock.lock()
        online = true
        let continuation = continuation
        lock.unlock()
        continuation?.yield(true)
    }
}

private actor MockNoteSyncService: NoteSyncing {
    private(set) var flushCallCount = 0

    nonisolated let syncOutcomes: AsyncStream<NoteSyncOutcome> = AsyncStream { $0.finish() }

    func flushPending() async {
        flushCallCount += 1
    }

    func pullVaultHeaderIfLocalMissing() async throws -> Data? {
        nil
    }

    func pullRemoteNotesCatalog() async throws {}

    func pullCatalogIfLocalVaultMissing() async throws -> Data? {
        nil
    }

    func uploadVaultHeaderOrThrow(_ header: Data) async throws {}

    nonisolated func scheduleFlush() {
        Task { await flushPending() }
    }

    nonisolated func scheduleVaultHeaderUpload(_ header: Data) {}
}
