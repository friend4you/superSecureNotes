import Foundation

public struct LoginResult: Equatable, Sendable {
    public let wasFirstSetup: Bool

    public init(wasFirstSetup: Bool) {
        self.wasFirstSetup = wasFirstSetup
    }
}

public struct RegisterResult: Equatable, Sendable {
    public let wasFirstSetup: Bool

    public init(wasFirstSetup: Bool) {
        self.wasFirstSetup = wasFirstSetup
    }
}

public enum BiometricUnlockResult: Equatable, Sendable {
    case success(password: String)
    case passwordEntryRequired
}
