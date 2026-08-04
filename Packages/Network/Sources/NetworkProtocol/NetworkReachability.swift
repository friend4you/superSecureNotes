import Foundation

public protocol NetworkReachability: Sendable {
    var isOnline: Bool { get }
    var changes: AsyncStream<Bool> { get }
}
