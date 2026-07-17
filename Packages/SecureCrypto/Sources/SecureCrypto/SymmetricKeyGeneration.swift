import CryptoKit
import Foundation

public func generateSymmetricKey() -> SymmetricKey {
    SymmetricKey(size: .bits256)
}
