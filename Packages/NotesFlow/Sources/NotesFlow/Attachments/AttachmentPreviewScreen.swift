#if os(iOS)
import SwiftUI

struct AttachmentPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPreviewReady = false

    let fileURL: URL

    var body: some View {
        NavigationStack {
            ZStack {
                QuickLookPreview(fileURL: fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .opacity(isPreviewReady ? 1 : 0)

                if !isPreviewReady {
                    ProgressView(NotesFlowUILocalization.localized("common.loading"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NotesFlowUILocalization.localized("common.close")) {
                        dismiss()
                    }
                }
            }
            .task {
                await AttachmentPreviewSupport.waitUntilPreviewReady(fileURL: fileURL)
                isPreviewReady = true
            }
        }
    }
}
#endif
