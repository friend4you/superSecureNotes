import Foundation

@MainActor
public protocol DeleteAccountUseCase: AnyObject {
    func execute(password: String) async throws
}
