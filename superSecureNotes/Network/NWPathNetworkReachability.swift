import AuthFlowProtocol
import AuthRepositoryProtocol
import CredentialStoreProtocol
import CredentialStoreProtocol
import Foundation
import Network
import VaultSessionProtocol

public final class NWPathNetworkReachability: NetworkReachability, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.superSecureNotes.networkReachability")
    private var online = true

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.online = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }

    public var isOnline: Bool { online }
}
