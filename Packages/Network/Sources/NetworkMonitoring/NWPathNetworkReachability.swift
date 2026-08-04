import Foundation
import Network
import NetworkProtocol

public final class NWPathNetworkReachability: NetworkReachability, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.superSecureNotes.networkReachability")
    private let lock = NSLock()
    private var online: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init() {
        online = monitor.currentPath.status == .satisfied
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateOnline(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    public var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return online
    }

    public var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = online
            lock.unlock()
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    private func updateOnline(_ isOnline: Bool) {
        lock.lock()
        online = isOnline
        let activeContinuations = Array(continuations.values)
        lock.unlock()
        activeContinuations.forEach { $0.yield(isOnline) }
    }
}
