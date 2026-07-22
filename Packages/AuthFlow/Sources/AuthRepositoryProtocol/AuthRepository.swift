import Foundation

public protocol AuthRepository: Sendable {
    var currentSession: AuthSession? { get async }
    var currentUser: User? { get async }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession
    func login(_ credentials: LoginCredentials) async throws -> AuthSession
    func logout() async throws
    func refreshSession() async throws -> AuthSession
}
