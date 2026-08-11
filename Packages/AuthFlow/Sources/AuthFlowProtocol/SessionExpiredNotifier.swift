import Foundation

public final class SessionExpiredNotifier: @unchecked Sendable {
    private let lock = NSLock()
    private var flagged = false

    public init() {}

    public func flagSessionExpired() {
        lock.lock()
        flagged = true
        lock.unlock()
    }

    public func consumeSessionExpiredFlag() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let wasFlagged = flagged
        flagged = false
        return wasFlagged
    }
}
