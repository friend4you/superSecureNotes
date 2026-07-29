import SwiftUI

struct NoteAttachmentsSection: View {
    let items: [NoteAttachmentItem]
    let dataForPreview: (String) -> Data?
    let onRemove: (String) -> Void

    @State private var previewFileURL: URL?
    @State private var showsPreview = false

    private let previewStore = AttachmentPreviewStore()

    var body: some View {
        Group {
            if !items.isEmpty {
                Section(NotesFlowUILocalization.localized("notes.detail.attachments")) {
                    ForEach(items) { item in
                        attachmentRow(for: item)
                    }
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showsPreview, onDismiss: cleanupPreview) {
            if let previewFileURL {
                QuickLookPreview(fileURL: previewFileURL)
                    .ignoresSafeArea()
            }
        }
        #endif
    }

    @ViewBuilder
    private func attachmentRow(for item: NoteAttachmentItem) -> some View {
        HStack {
            #if os(iOS)
            Button {
                openPreview(for: item)
            } label: {
                Text(item.filename)
                    .foregroundStyle(.primary)
            }
            #else
            Text(item.filename)
            #endif

            Spacer()

            Button(role: .destructive) {
                onRemove(item.id)
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel(NotesFlowUILocalization.localized("notes.attachments.remove"))
        }
    }

    #if os(iOS)
    private func openPreview(for item: NoteAttachmentItem) {
        guard let data = dataForPreview(item.id) else { return }

        do {
            let fileURL = try previewStore.writePreviewFile(data: data, filename: item.filename)
            previewFileURL = fileURL
            showsPreview = true
        } catch {
            return
        }
    }

    private func cleanupPreview() {
        if let previewFileURL {
            previewStore.deletePreviewFile(at: previewFileURL)
            self.previewFileURL = nil
        }
    }
    #endif
}
