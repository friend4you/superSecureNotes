import Foundation

@MainActor
public protocol LoginUseCase: AnyObject {
    func execute(email: String, password: String) async throws -> LoginResult
}
