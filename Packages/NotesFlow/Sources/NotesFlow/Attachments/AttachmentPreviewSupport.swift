#if os(iOS)
import QuickLook
#endif
import Foundation

enum AttachmentPreviewSupport {
    #if os(iOS)
    static func canPreview(fileURL: URL) -> Bool {
        QLPreviewController.canPreview(fileURL as QLPreviewItem)
    }
    #else
    static func canPreview(fileURL: URL) -> Bool {
        _ = fileURL
        return false
    }
    #endif
}
