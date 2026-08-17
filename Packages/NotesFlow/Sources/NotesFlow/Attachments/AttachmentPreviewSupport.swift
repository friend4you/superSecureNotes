#if os(iOS)
import CoreGraphics
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers
#endif
import Foundation

enum AttachmentPreviewSupport {
    #if os(iOS)
    static func canPreview(fileURL: URL) -> Bool {
        QLPreviewController.canPreview(fileURL as QLPreviewItem)
    }

    static func waitUntilPreviewReady(fileURL: URL) async {
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 64, height: 64),
            scale: 1,
            representationTypes: .thumbnail
        )
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { _, _ in
                once.resume()
            }
            Task {
                try? await Task.sleep(for: previewReadinessTimeout(for: fileURL))
                QLThumbnailGenerator.shared.cancel(request)
                once.resume()
            }
        }
    }

    static func previewReadinessTimeout(for fileURL: URL) -> Duration {
        guard let type = UTType(filenameExtension: fileURL.pathExtension) else {
            return .milliseconds(250)
        }
        if type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .audiovisualContent) {
            return .seconds(2)
        }
        return .milliseconds(250)
    }
    #else
    static func canPreview(fileURL: URL) -> Bool {
        _ = fileURL
        return false
    }

    static func waitUntilPreviewReady(fileURL: URL) async {
        _ = fileURL
    }
    #endif
}

#if os(iOS)
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume()
    }
}
#endif
