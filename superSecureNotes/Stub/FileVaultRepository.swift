import Foundation
import VaultRepositoryProtocol

#if DEBUG

actor FileVaultRepository: VaultRepository {
    private let directoryURL: URL

    private var headerFileURL: URL {
        directoryURL.appendingPathComponent("vault-header.bin", isDirectory: false)
    }

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directoryURL = appSupport.appendingPathComponent("stub-vault", isDirectory: true)
        }
    }

    func readHeader() async throws -> Data {
        guard FileManager.default.fileExists(atPath: headerFileURL.path) else {
            throw VaultRepositoryError.headerNotFound
        }
        return try Data(contentsOf: headerFileURL)
    }

    func writeHeader(_ header: Data) async throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try header.write(to: headerFileURL, options: .atomic)
    }

    func fetchPublicKey(userID: String) async throws -> Data {
        Data(repeating: 0, count: 32)
    }
}

#endif
