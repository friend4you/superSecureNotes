import Foundation

@MainActor
public protocol RegisterUseCase: AnyObject {
    func execute(email: String, password: String) async throws -> RegisterResult
}
