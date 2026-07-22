import CryptoKit
import Foundation

public actor VaultSession: VaultSessionProtocol.VaultSession {
    private var keys: VaultSessionKeys?
    private var subscribers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init() {}

    public var isActive: Bool {
        keys != nil
    }

    public nonisolated var changes: AsyncStream<Bool> {
        AsyncStream { continuation in
            Task {
                await self.addSubscriber(continuation)
            }
        }
    }

    public func establish(_ keys: VaultSessionKeys) {
        self.keys = keys
        notify(true)
    }

    public func clear() {
        guard keys != nil else {
            return
        }
        keys = nil
        notify(false)
    }

    public func udk() throws -> SymmetricKey {
        guard let keys else {
            throw VaultSessionError.notActive
        }
        return keys.udk
    }

    public func identityPrivateKey() throws -> Data {
        guard let keys else {
            throw VaultSessionError.notActive
        }
        return keys.identityPrivateKey
    }

    private func addSubscriber(_ continuation: AsyncStream<Bool>.Continuation) {
        let id = UUID()
        continuation.yield(isActive)
        subscribers[id] = continuation
        continuation.onTermination = { @Sendable _ in
            Task { await self.removeSubscriber(id) }
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    private func notify(_ value: Bool) {
        for continuation in subscribers.values {
            continuation.yield(value)
        }
    }
}
