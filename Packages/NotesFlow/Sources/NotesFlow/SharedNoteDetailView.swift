import SwiftUI

public struct SharedNoteDetailView: View {
    @Bindable private var viewModel: DefaultSharedNoteDetailViewModel
    #if os(iOS)
    @State private var attachmentPreview: AttachmentPreviewPresentation?
    #endif

    public init(viewModel: DefaultSharedNoteDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView(NotesFlowUILocalization.localized("common.loading"))
                        Spacer()
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !viewModel.ownerEmail.isEmpty {
                Section(NotesFlowUILocalization.localized("notes.shared.detail.owner")) {
                    Text(viewModel.ownerEmail)
                }
            }

            Section {
                Text(viewModel.title)
            }

            Section {
                Text(viewModel.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NoteAttachmentsSection(
                items: viewModel.attachmentItems,
                dataForPreview: viewModel.attachmentData(for:),
                onRemove: { _ in },
                onPreview: { url in
                    #if os(iOS)
                    attachmentPreview = AttachmentPreviewPresentation(fileURL: url)
                    #endif
                },
                allowsRemoval: false,
                progressByID: viewModel.attachmentProgressByID,
                onRetry: { id in
                    Task {
                        await viewModel.retryAttachment(id: id)
                    }
                }
            )
        }
        #if os(iOS)
        .attachmentPreview($attachmentPreview)
        #endif
        .navigationTitle(NotesFlowUILocalization.localized("notes.shared.detail.title"))
        .task(id: viewModel.noteID) {
            await viewModel.load()
        }
    }
}
