import AuthFlowProtocol
import Foundation
import LocalAuthentication

public struct LAContextEvaluating: Sendable {
    private let canEvaluateBiometricsHandler: @Sendable () -> Bool
    private let evaluatePolicyHandler: @Sendable (String) async -> BiometricAuthResult

    public init(makeContext: @escaping @Sendable () -> LAContext = { LAContext() }) {
        canEvaluateBiometricsHandler = {
            var error: NSError?
            let context = makeContext()
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
        evaluatePolicyHandler = { reason in
            let context = makeContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                return .unavailable
            }

            return await withCheckedContinuation { continuation in
                context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                ) { success, error in
                    if success {
                        continuation.resume(returning: .success)
                    } else if let error = error as? LAError, error.code == .userCancel {
                        continuation.resume(returning: .cancelled)
                    } else {
                        continuation.resume(returning: .failed)
                    }
                }
            }
        }
    }

    init(
        canEvaluateBiometrics: @escaping @Sendable () -> Bool,
        evaluatePolicy: @escaping @Sendable (String) async -> BiometricAuthResult
    ) {
        self.canEvaluateBiometricsHandler = canEvaluateBiometrics
        self.evaluatePolicyHandler = evaluatePolicy
    }

    func canEvaluateBiometrics() -> Bool {
        canEvaluateBiometricsHandler()
    }

    func evaluatePolicy(reason: String) async -> BiometricAuthResult {
        await evaluatePolicyHandler(reason)
    }
}

public struct LocalAuthenticationBiometricAuthenticator: BiometricAuthenticator {
    private let contextFactory: LAContextEvaluating

    public init(contextFactory: LAContextEvaluating = LAContextEvaluating()) {
        self.contextFactory = contextFactory
    }

    public func canEvaluateBiometrics() -> Bool {
        contextFactory.canEvaluateBiometrics()
    }

    public func authenticate(reason: String) async -> BiometricAuthResult {
        await contextFactory.evaluatePolicy(reason: reason)
    }
}
