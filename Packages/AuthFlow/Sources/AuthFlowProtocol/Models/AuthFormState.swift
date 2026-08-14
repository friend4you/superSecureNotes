import Foundation

public enum AuthFormState: Equatable, Sendable {
    case idle
    case loading
    case failure(AuthFlowError)
}
