import Foundation

@MainActor
public protocol EstablishVaultSessionUseCase: AnyObject {
    func execute(
        headerData: Data,
        password: String,
        policy: EstablishVaultSessionPolicy
    ) async throws
}
