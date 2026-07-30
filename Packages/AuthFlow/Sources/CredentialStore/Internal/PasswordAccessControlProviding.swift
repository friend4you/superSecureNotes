import CredentialStoreProtocol
import Foundation
import Security

public enum PasswordAccessMode: Sendable {
    case biometric
    case standard
}

protocol PasswordAccessControlProviding: Sendable {
    func makePasswordAccessControl() throws -> SecAccessControl
}

struct BiometricPasswordAccessControl: PasswordAccessControlProviding {
    func makePasswordAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        ) else {
            throw CredentialStoreError.storageFailed
        }
        return accessControl
    }
}

struct StandardPasswordAccessControl: PasswordAccessControlProviding {
    func makePasswordAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [],
            &error
        ) else {
            throw CredentialStoreError.storageFailed
        }
        return accessControl
    }
}

func makePasswordAccessControlProvider(
    for mode: PasswordAccessMode
) -> any PasswordAccessControlProviding {
    switch mode {
    case .biometric:
        BiometricPasswordAccessControl()
    case .standard:
        StandardPasswordAccessControl()
    }
}
