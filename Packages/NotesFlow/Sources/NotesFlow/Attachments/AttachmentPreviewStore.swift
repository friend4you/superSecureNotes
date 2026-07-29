import Foundation

struct AttachmentPreviewStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func writePreviewFile(data: Data, filename: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("notes-attachment-preview", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func deletePreviewFile(at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? fileManager.removeItem(at: directory)
    }
}
