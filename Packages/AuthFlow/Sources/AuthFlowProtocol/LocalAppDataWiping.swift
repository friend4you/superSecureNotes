import Foundation

public protocol LocalAppDataWiping: Sendable {
    func wipeAll() async throws
}

public struct FileSystemLocalAppDataWiper: LocalAppDataWiping {
    private let rootURL: URL
    private let fileManager: FileManager

    public init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.rootURL = appSupport
                .appendingPathComponent("superSecureNotes", isDirectory: true)
        }
    }

    public func wipeAll() async throws {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return
        }
        try fileManager.removeItem(at: rootURL)
    }
}
