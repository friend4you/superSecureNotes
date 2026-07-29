import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public struct NoteDetailView: View {
    @Bindable private var viewModel: DefaultNoteDetailViewModel
    @State private var showsDeleteConfirmation = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showsFileImporter = false

    public init(viewModel: DefaultNoteDetailViewModel) {
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

            Section {
                TextField(
                    NotesFlowUILocalization.localized("notes.detail.titleField"),
                    text: $viewModel.title
                )
            }

            Section {
                TextEditor(text: $viewModel.body)
                    .frame(minHeight: 200)
            }

            Section {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label(
                        NotesFlowUILocalization.localized("notes.create.addPhoto"),
                        systemImage: "photo"
                    )
                }
                .onChange(of: selectedPhotoItem) { _, newValue in
                    guard let newValue else { return }
                    Task {
                        await importPhoto(from: newValue)
                        selectedPhotoItem = nil
                    }
                }

                Button {
                    showsFileImporter = true
                } label: {
                    Label(
                        NotesFlowUILocalization.localized("notes.create.addFile"),
                        systemImage: "doc"
                    )
                }
            }

            NoteAttachmentsSection(
                items: viewModel.attachmentItems,
                dataForPreview: viewModel.attachmentData(for:),
                onRemove: viewModel.removeAttachment(id:)
            )
        }
        .navigationTitle(NotesFlowUILocalization.localized("notes.detail.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(NotesFlowUILocalization.localized("common.save")) {
                    Task {
                        await viewModel.save()
                    }
                }
                .disabled(!viewModel.canSave)
            }

            ToolbarItem(placement: .automatic) {
                Button(NotesFlowUILocalization.localized("common.share")) {
                    viewModel.share()
                }
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
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
            Text(NotesFlowUILocalization.localized("notes.delete.confirmation"))
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image, .pdf, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    try importFile(from: url)
                } catch {
                    viewModel.reportError(error.localizedDescription)
                }
            case .failure(let error):
                viewModel.reportError(error.localizedDescription)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        guard let attachment = await NoteAttachmentImportSupport.attachment(from: item) else {
            return
        }

        viewModel.addAttachment(attachment)
    }

    private func importFile(from url: URL) throws {
        viewModel.addAttachment(try NoteAttachmentImportSupport.attachment(from: url))
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(
            viewModel: DefaultNoteDetailViewModel(
                noteID: UUID(),
                noteRepository: PreviewNoteRepository(),
                vaultSession: PreviewVaultSession(),
                navigator: PreviewNavigator()
            )
        )
    }
}

#if DEBUG
import AuthRepositoryProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import VaultSessionProtocol

private actor PreviewNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> Data { Data() }
    func writeNote(noteID: UUID, data: Data) async throws {}
    func deleteNote(noteID: UUID) async throws {}
}

private actor PreviewVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}

@MainActor
private final class PreviewNavigator: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}
#endif
