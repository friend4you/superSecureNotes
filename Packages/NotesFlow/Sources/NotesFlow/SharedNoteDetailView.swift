import SwiftUI

public struct SharedNoteDetailView: View {
    @Bindable private var viewModel: DefaultSharedNoteDetailViewModel
    @State private var showsDeleteConfirmation = false
    #if os(iOS)
    @State private var attachmentPreview: AttachmentPreviewPresentation?
    @State private var previewUnavailableFilename: String?
    #endif

    public init(viewModel: DefaultSharedNoteDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Text(
            String(
                format: NotesFlowUILocalization.localized("notes.shared.detail.ownerCaption"),
                viewModel.ownerEmail
            )
        )
        .lineLimit(1)
        
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

            Section {
                Text(viewModel.title)
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
                onPreviewUnavailable: { filename in
                    #if os(iOS)
                    previewUnavailableFilename = filename
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
        .attachmentPreviewUnavailableAlert(filename: $previewUnavailableFilename)
        #endif
        .toolbar {
            if !viewModel.ownerEmail.isEmpty {
                ToolbarItem(placement: .principal) {
                    
                }
            }

            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #endif
        }
        .alert(
            NotesFlowUILocalization.localized("common.delete"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                Task {
                    await viewModel.delete()
                }
            }
            Button(NotesFlowUILocalization.localized("common.cancel"), role: .cancel) {}
        } message: {
            Text(NotesFlowUILocalization.localized("notes.shared.delete.confirmation"))
        }
        .task(id: viewModel.noteID) {
            await viewModel.load()
        }
    }
}
