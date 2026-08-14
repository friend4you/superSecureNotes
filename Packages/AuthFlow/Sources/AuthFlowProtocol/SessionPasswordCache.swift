import AuthFlowDomainProtocol
import Foundation

@MainActor
public final class SessionPasswordCache: SessionPasswordCaching {
    private var cachedPassword: String?

    public nonisolated init() {}

    public func store(_ password: String) {
        cachedPassword = password
    }

    public func password() -> String? {
        cachedPassword
    }

    public func clear() {
        cachedPassword = nil
    }
}
