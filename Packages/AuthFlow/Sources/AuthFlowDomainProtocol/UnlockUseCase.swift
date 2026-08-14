import Foundation

@MainActor
public protocol UnlockUseCase: AnyObject {
    func execute(password: String, email: String) async throws
}
