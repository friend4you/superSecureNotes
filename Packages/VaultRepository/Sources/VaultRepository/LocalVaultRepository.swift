import Foundation
import VaultRepositoryProtocol

public actor LocalVaultRepository: VaultRepository {
    private let vaultDirectoryURL: URL
    private let fileManager: FileManager

    private var headerFileURL: URL {
        vaultDirectoryURL.appendingPathComponent("vault-header.bin", isDirectory: false)
    }

    public init(vaultDirectoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let vaultDirectoryURL {
            self.vaultDirectoryURL = vaultDirectoryURL
        } else {
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.vaultDirectoryURL = appSupport
                .appendingPathComponent("superSecureNotes", isDirectory: true)
                .appendingPathComponent("vault", isDirectory: true)
        }
    }

    public func readHeader() async throws -> Data {
        guard fileManager.fileExists(atPath: headerFileURL.path) else {
            throw VaultRepositoryError.headerNotFound
        }
        return try Data(contentsOf: headerFileURL)
    }

    public func writeHeader(_ header: Data) async throws {
        try ensureVaultDirectory()
        try header.write(to: headerFileURL, options: .atomic)
    }

    public func fetchPublicKey(userID: String) async throws -> Data {
        Data(repeating: 0, count: 32)
    }

    private func ensureVaultDirectory() throws {
        try fileManager.createDirectory(
            at: vaultDirectoryURL,
            withIntermediateDirectories: true
        )
        try excludeFromBackup(vaultDirectoryURL)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
