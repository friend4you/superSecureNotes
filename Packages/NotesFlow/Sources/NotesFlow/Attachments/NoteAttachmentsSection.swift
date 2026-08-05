import SwiftUI

struct NoteAttachmentsSection: View {
    let items: [NoteAttachmentItem]
    let dataForPreview: (String) -> Data?
    let onRemove: (String) -> Void
    let onPreview: (URL) -> Void
    var allowsRemoval: Bool = true

    private let previewStore = AttachmentPreviewStore()

    var body: some View {
        if !items.isEmpty {
            Section(NotesFlowUILocalization.localized("notes.detail.attachments")) {
                ForEach(items) { item in
                    attachmentRow(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(for item: NoteAttachmentItem) -> some View {
        HStack {
            Text(item.filename)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                #if os(iOS)
                .onTapGesture {
                    openPreview(for: item)
                }
                #endif

            if allowsRemoval {
                Button {
                    onRemove(item.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(NotesFlowUILocalization.localized("notes.attachments.remove"))
            }
        }
    }

    #if os(iOS)
    private func openPreview(for item: NoteAttachmentItem) {
        guard let data = dataForPreview(item.id) else { return }

        do {
            let fileURL = try previewStore.writePreviewFile(data: data, filename: item.filename)
            onPreview(fileURL)
        } catch {
            return
        }
    }
    #endif
}