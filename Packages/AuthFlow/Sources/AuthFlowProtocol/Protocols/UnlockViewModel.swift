import Foundation

public enum UnlockFormState: Equatable, Sendable {
    case idle
    case awaitingPresence
    case passwordEntry
    case loading
    case failure(AuthFlowError)
}

@MainActor
public protocol UnlockViewModel: Observable {
    var email: String { get }
    var password: String { get set }
    var state: UnlockFormState { get }

    func onAppear() async
    func unlockWithPassword() async
    func retryBiometrics() async
}
