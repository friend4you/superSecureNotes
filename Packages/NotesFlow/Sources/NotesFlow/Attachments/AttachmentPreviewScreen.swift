#if os(iOS)
import SwiftUI

struct AttachmentPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let fileURL: URL

    var body: some View {
        NavigationStack {
            QuickLookPreview(fileURL: fileURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(fileURL.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NotesFlowUILocalization.localized("common.close")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}
#endif
