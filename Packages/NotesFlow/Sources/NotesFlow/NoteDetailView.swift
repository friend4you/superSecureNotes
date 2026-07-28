import SwiftUI

public struct NoteDetailView: View {
    @Bindable private var viewModel: DefaultNoteDetailViewModel
    @State private var showsDeleteConfirmation = false

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

            if !viewModel.attachmentFilenames.isEmpty {
                Section(NotesFlowUILocalization.localized("notes.detail.attachments")) {
                    ForEach(viewModel.attachmentFilenames, id: \.self) { filename in
                        Text(filename)
                    }
                }
            }
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
        .task {
            await viewModel.load()
        }
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
