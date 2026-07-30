#if os(iOS)
import SwiftUI

struct AttachmentPreviewPresentation: Identifiable {
    let id = UUID()
    let fileURL: URL
}

private struct AttachmentPreviewModifier: ViewModifier {
    @Binding var presentation: AttachmentPreviewPresentation?

    private let previewStore = AttachmentPreviewStore()

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presentation, onDismiss: cleanupPreview) { presentation in
                AttachmentPreviewScreen(fileURL: presentation.fileURL)
            }
    }

    private func cleanupPreview() {
        let fileURL = presentation?.fileURL
        presentation = nil
        if let fileURL {
            previewStore.deletePreviewFile(at: fileURL)
        }
    }
}

extension View {
    func attachmentPreview(_ presentation: Binding<AttachmentPreviewPresentation?>) -> some View {
        modifier(AttachmentPreviewModifier(presentation: presentation))
    }
}
#endif
