import Foundation

public protocol PendingBiometricEnrollmentStoring {
    var isPending: Bool { get }
    func setPending(_ pending: Bool)
}

public final class UserDefaultsPendingBiometricEnrollmentStore: PendingBiometricEnrollmentStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "pendingBiometricEnrollment"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var isPending: Bool {
        defaults.bool(forKey: key)
    }

    public func setPending(_ pending: Bool) {
        defaults.set(pending, forKey: key)
    }
}
