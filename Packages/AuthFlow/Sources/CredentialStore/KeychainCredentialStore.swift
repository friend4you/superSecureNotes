import CredentialStoreProtocol
import Foundation
import Security

public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let passwordAccessMode: PasswordAccessMode

    public init(
        service: String = "com.superSecureNotes.credentials",
        passwordAccessMode: PasswordAccessMode = .biometric
    ) {
        self.service = service
        self.passwordAccessMode = passwordAccessMode
    }

    public var hasLocalSetup: Bool {
        readBool(for: .hasLocalSetup) ?? false
    }

    public func markSetupComplete() throws {
        try saveBool(true, for: .hasLocalSetup)
    }

    public func saveEmail(_ email: String) throws {
        try saveString(email, for: .email)
    }

    public func email() -> String? {
        readString(for: .email)
    }

    public func saveRefreshToken(_ token: String) throws {
        try saveString(token, for: .refreshToken)
    }

    public func refreshToken() -> String? {
        readString(for: .refreshToken)
    }

    public func saveVaultHeader(_ header: Data) throws {
        try saveData(header, for: .vaultHeader)
    }

    public func vaultHeader() -> Data? {
        readData(for: .vaultHeader)
    }

    public func bioEnabled() -> Bool {
        readBool(for: .bioEnabled) ?? false
    }

    public func setBioEnabled(_ enabled: Bool) throws {
        try saveBool(enabled, for: .bioEnabled)
        if !enabled {
            try deleteItem(for: .password)
        }
    }

    public func savePassword(_ password: String) throws {
        guard bioEnabled() else {
            throw CredentialStoreError.storageFailed
        }
        if passwordAccessMode == .biometric {
            let accessControl = try makePasswordAccessControlProvider(for: .biometric)
                .makePasswordAccessControl()
            try saveString(password, for: .password, accessControl: accessControl)
        } else {
            try saveString(password, for: .password)
        }
    }

    public func loadPasswordWithBiometrics() throws -> String {
        guard bioEnabled() else {
            throw CredentialStoreError.itemNotFound
        }
        guard let password = readString(for: .password) else {
            throw CredentialStoreError.itemNotFound
        }
        return password
    }

    public func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {
        try saveEmail(email)
        try saveRefreshToken(refreshToken)
        try saveVaultHeader(vaultHeader)
        try markSetupComplete()
    }

    public func clearAll() throws {
        for item in KeychainItem.allCases {
            try deleteItem(for: item)
        }
    }

    private func saveString(
        _ value: String,
        for item: KeychainItem,
        accessControl: SecAccessControl? = nil
    ) throws {
        guard let data = value.data(using: .utf8) else {
            throw CredentialStoreError.storageFailed
        }
        try saveData(data, for: item, accessControl: accessControl)
    }

    private func saveBool(_ value: Bool, for item: KeychainItem) throws {
        try saveString(value ? "true" : "false", for: item)
    }

    private func saveData(
        _ data: Data,
        for item: KeychainItem,
        accessControl: SecAccessControl? = nil
    ) throws {
        try deleteItem(for: item)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
            kSecValueData as String: data,
        ]

        if let accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.storageFailed
        }
    }

    private func readString(for item: KeychainItem) -> String? {
        guard let data = readData(for: item) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func readBool(for item: KeychainItem) -> Bool? {
        guard let value = readString(for: item) else {
            return nil
        }
        return value == "true"
    }

    private func readData(for item: KeychainItem) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private func deleteItem(for item: KeychainItem) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.storageFailed
        }
    }
}
