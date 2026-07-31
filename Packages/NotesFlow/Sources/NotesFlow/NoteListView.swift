import SwiftUI

public struct NoteListView: View {
    @Bindable private var viewModel: DefaultNoteListViewModel
    @State private var pendingDeleteNoteID: UUID?

    public init(viewModel: DefaultNoteListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView(NotesFlowUILocalization.localized("common.loading"))
                    Spacer()
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            ForEach(viewModel.notes, id: \.noteID) { note in
                Text(note.title)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.openDetail(noteID: note.noteID)
                    }
                    .contextMenu {
                        Button(NotesFlowUILocalization.localized("common.share")) {
                            viewModel.share(noteID: note.noteID)
                        }
                        Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                            pendingDeleteNoteID = note.noteID
                        }
                    }
            }
        }
        .navigationTitle(NotesFlowUILocalization.localized("notes.list.title"))
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createNote()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NotesFlowUILocalization.localized("notes.create.title"))
            }

            ToolbarItem(placement: .automatic) {
                Button(NotesFlowUILocalization.localized("notes.list.settings")) {
                    viewModel.openSettings()
                }
            }

            #if DEBUG
            ToolbarItem(placement: .automatic) {
                Button(NotesFlowUILocalization.localized("notes.list.logout")) {
                    Task {
                        await viewModel.logout()
                    }
                }
            }
            #endif
        }
        .alert(
            NotesFlowUILocalization.localized("common.delete"),
            isPresented: Binding(
                get: { pendingDeleteNoteID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteNoteID = nil
                    }
                }
            ),
            presenting: pendingDeleteNoteID
        ) { noteID in
            Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                Task {
                    await viewModel.deleteNote(noteID: noteID)
                    pendingDeleteNoteID = nil
                }
            }
            Button(NotesFlowUILocalization.localized("common.cancel"), role: .cancel) {
                pendingDeleteNoteID = nil
            }
        } message: { _ in
            Text(NotesFlowUILocalization.localized("notes.delete.confirmation"))
        }
    }
}

#Preview {
    NavigationStack {
        NoteListView(
            viewModel: DefaultNoteListViewModel(
                authRepository: PreviewAuthRepository(),
                vaultSession: PreviewVaultSession(),
                noteRepository: PreviewNoteRepository(),
                navigator: PreviewNavigator(),
                credentialStore: PreviewCredentialStore(),
                performLogout: {}
            )
        )
    }
}

#if DEBUG
import AuthRepositoryProtocol
import CredentialStoreProtocol
import CryptoKit
import NavigationProtocol
import NoteRepositoryProtocol
import SecureCrypto
import VaultSessionProtocol

private actor PreviewAuthRepository: AuthRepository {
    var currentSession: AuthSession? { nil }
    var currentUser: User? { nil }
    func register(_ credentials: RegisterCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func login(_ credentials: LoginCredentials) async throws -> AuthSession {
        AuthSession(accessToken: "", refreshToken: "", expiresAt: .distantFuture)
    }
    func logout() async throws {}
    func refreshSession() async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func restoreSession(refreshToken: String) async throws -> AuthSession {
        throw AuthRepositoryError.notAuthenticated
    }

    func clearSession() async {}
}

private final class PreviewCredentialStore: CredentialStore, @unchecked Sendable {
    var hasLocalSetup: Bool { false }
    func markSetupComplete() throws {}
    func saveEmail(_ email: String) throws {}
    func email() -> String? { nil }
    func saveRefreshToken(_ token: String) throws {}
    func refreshToken() -> String? { nil }
    func saveVaultHeader(_ header: Data) throws {}
    func vaultHeader() -> Data? { nil }
    func bioEnabled() -> Bool { false }
    func setBioEnabled(_ enabled: Bool) throws {}
    func savePassword(_ password: String) throws {}
    func loadPasswordWithBiometrics() throws -> String { throw CredentialStoreError.itemNotFound }
    func saveSetup(email: String, refreshToken: String, vaultHeader: Data) throws {}
    func clearAll() throws {}
}

private actor PreviewVaultSession: VaultSessionProtocol {
    var isActive: Bool { false }
    nonisolated var changes: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func establish(_ keys: VaultSessionKeys) {}
    func clear() {}
    func udk() throws -> SymmetricKey { .init(size: .bits256) }
    func identityPrivateKey() throws -> Data { Data() }
}

private actor PreviewNoteRepository: NoteRepository {
    func listNotes() async throws -> [NoteSummary] { [] }
    func readNote(noteID: UUID) async throws -> StoredNote {
        StoredNote(
            metadata: NoteMetadata(
                noteID: noteID,
                title: "",
                createdAt: 0,
                updatedAt: 0,
                attachmentCount: 0,
                attachmentsTotalSize: 0
            ),
            wrappedFEK: Data(),
            encryptedPayload: Data([0x01]),
            syncState: .pendingSync
        )
    }
    func writeNote(_ note: StoredNote) async throws {}
    func deleteNote(noteID: UUID) async throws {}
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
