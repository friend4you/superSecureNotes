import Foundation

@MainActor
public protocol RestoreOnlineSessionUseCase: AnyObject {
    func execute(email: String, password: String) async throws
}
