import Foundation

@MainActor
public protocol BiometricUnlockUseCase: AnyObject {
    func execute() async -> BiometricUnlockResult
}
