import Network
import NetworkProtocol

public final class NWPathNetworkReachability: NetworkReachability, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.superSecureNotes.networkReachability")
    private var online: Bool

    public init() {
        online = monitor.currentPath.status == .satisfied
        monitor.pathUpdateHandler = { [weak self] path in
            self?.online = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    public var isOnline: Bool { online }
}
