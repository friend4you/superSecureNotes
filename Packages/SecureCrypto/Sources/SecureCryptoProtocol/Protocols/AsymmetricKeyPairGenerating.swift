import Foundation

public protocol AsymmetricKeyPairGenerating: Sendable {
    func generateKeyPair() -> (publicKey: Data, privateKey: Data)
}
