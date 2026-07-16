import Foundation

public enum SecureCryptoError: Error, Equatable, Sendable {
    case insufficientData
    case invalidMagic(expected: String, actual: String)
    case unsupportedVersion(UInt8)
    case authenticationFailed
    case invalidInput(String)
    case decodingFailed(String)
}

extension SecureCryptoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Unexpected end of data while parsing binary format."
        case let .invalidMagic(expected, actual):
            return "Invalid magic bytes: expected \(expected), got \(actual)."
        case let .unsupportedVersion(version):
            return "Unsupported format version: \(version)."
        case .authenticationFailed:
            return "Authentication failed; data may be corrupted or the key is incorrect."
        case let .invalidInput(message):
            return message
        case let .decodingFailed(message):
            return "Decoding failed: \(message)."
        }
    }
}
