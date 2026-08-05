import Foundation
import NoteRepositoryProtocol

/// Fan-out helper so multiple `for await` loops each receive every sync outcome.
final class NoteSyncOutcomeMulticaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<NoteSyncOutcome>.Continuation] = [:]

    func stream() -> AsyncStream<NoteSyncOutcome> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                lock.lock()
                continuations.removeValue(forKey: id)
                lock.unlock()
            }
        }
    }

    func yield(_ outcome: NoteSyncOutcome) {
        lock.lock()
        let subscribers = Array(continuations.values)
        lock.unlock()
        for continuation in subscribers {
            continuation.yield(outcome)
        }
    }
}
