import Foundation

public protocol NetworkReachability: Sendable {
    var isOnline: Bool { get }
}
