import AuthFlowProtocol
import SwiftUI

enum AuthFlowErrorText {
    static func localized(_ error: AuthFlowError) -> String {
        switch error {
        case .invalidCredentials:
            return String(localized: "error.invalidCredentials", bundle: .module)
        case .emailAlreadyExists:
            return String(localized: "error.emailAlreadyExists", bundle: .module)
        case let .validationError(message):
            if let message, !message.isEmpty {
                return message
            }
            return String(localized: "error.validationError", bundle: .module)
        case .vaultNotFound:
            return String(localized: "error.vaultNotFound", bundle: .module)
        case .vaultUnlockFailed:
            return String(localized: "error.vaultUnlockFailed", bundle: .module)
        case .networkError:
            return String(localized: "error.networkError", bundle: .module)
        case .networkRequired:
            return String(localized: "error.networkRequired", bundle: .module)
        case .sessionExpired:
            return String(localized: "error.sessionExpired", bundle: .module)
        case .unknown:
            return String(localized: "error.unknown", bundle: .module)
        }
    }
}
