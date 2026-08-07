import SwiftUI

struct NoteAttachmentsSection: View {
    let items: [NoteAttachmentItem]
    let dataForPreview: (String) -> Data?
    let onRemove: (String) -> Void
    let onPreview: (URL) -> Void
    var allowsRemoval: Bool = true
    var progressByID: [String: AttachmentRowProgress] = [:]
    var onRetry: (String) -> Void = { _ in }

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
            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    #if os(iOS)
                    .onTapGesture {
                        openPreview(for: item)
                    }
                    #endif

                if let progress = progressByID[item.id], progress.state != .completed {
                    if progress.state == .downloading {
                        ProgressView(value: progress.fractionCompleted)
                            .accessibilityLabel(NotesFlowUILocalization.localized("notes.attachments.downloading"))
                    } else if progress.state == .failed {
                        HStack {
                            Text(NotesFlowUILocalization.localized("notes.attachments.downloadFailed"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(NotesFlowUILocalization.localized("notes.attachments.retry")) {
                                onRetry(item.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

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
