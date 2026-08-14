import Foundation

public enum EstablishVaultSessionPolicy: Sendable {
    case firstLoginWithRemoteHeader
    case afterLocalCreate
    case standardUnlock
}
