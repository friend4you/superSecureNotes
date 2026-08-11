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

    func attachmentPreviewUnavailableAlert(filename: Binding<String?>) -> some View {
        alert(
            NotesFlowUILocalization.localized("notes.attachments.previewUnavailable.title"),
            isPresented: Binding(
                get: { filename.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        filename.wrappedValue = nil
                    }
                }
            )
        ) {
            Button(NotesFlowUILocalization.localized("common.close"), role: .cancel) {}
        } message: {
            if let unavailableFilename = filename.wrappedValue {
                Text(
                    String(
                        format: NotesFlowUILocalization.localized(
                            "notes.attachments.previewUnavailable.message"
                        ),
                        unavailableFilename
                    )
                )
            }
        }
    }
}
#endif
