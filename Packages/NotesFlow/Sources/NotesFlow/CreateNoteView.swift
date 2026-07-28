import PhotosUI
import SecureCrypto
import SwiftUI
import UniformTypeIdentifiers

public struct CreateNoteView: View {
    @Bindable private var viewModel: DefaultCreateNoteViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showsFileImporter = false

    public init(viewModel: DefaultCreateNoteViewModel) {
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

            if !viewModel.attachmentFilenames.isEmpty {
                Section(NotesFlowUILocalization.localized("notes.detail.attachments")) {
                    ForEach(viewModel.attachmentFilenames, id: \.self) { filename in
                        Text(filename)
                    }
                }
            }
        }
        .navigationTitle(NotesFlowUILocalization.localized("notes.create.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(NotesFlowUILocalization.localized("common.save")) {
                    Task {
                        await viewModel.save()
                    }
                }
                .disabled(!viewModel.canSave)
            }
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
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        guard let photoData = try? await item.loadTransferable(type: PhotoPickerData.self) else {
            return
        }

        viewModel.addAttachment(
            NotePayload.Attachment(
                id: UUID().uuidString,
                filename: photoData.filename,
                mime: photoData.mimeType,
                data: photoData.data
            )
        )
    }

    private func importFile(from url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
        viewModel.addAttachment(
            NotePayload.Attachment(
                id: UUID().uuidString,
                filename: url.lastPathComponent,
                mime: contentType.preferredMIMEType ?? "application/octet-stream",
                data: data
            )
        )
    }
}

private struct PhotoPickerData: Transferable {
    let data: Data
    let filename: String
    let mimeType: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PhotoPickerData(
                data: data,
                filename: "photo.jpg",
                mimeType: UTType.image.preferredMIMEType ?? "image/jpeg"
            )
        }
    }
}

#Preview {
    NavigationStack {
        CreateNoteView(
            viewModel: DefaultCreateNoteViewModel(
                noteRepository: PreviewNoteRepository(),
                vaultSession: PreviewVaultSession(),
                navigator: PreviewNavigator()
            )
        )
    }
}

#if DEBUG
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
