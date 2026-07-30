import Foundation

enum KeychainItem: String, CaseIterable, Sendable {
    case email
    case refreshToken
    case password
    case vaultHeader
    case bioEnabled
    case hasLocalSetup
}
