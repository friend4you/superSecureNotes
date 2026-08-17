import SwiftUI

public struct NoteListView: View {
    @Bindable private var viewModel: DefaultNoteListViewModel
    @State private var pendingDeleteNoteID: UUID?
    @State private var pendingDeleteSharedNoteID: UUID?

    public init(viewModel: DefaultNoteListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TabView(selection: $viewModel.selectedSegment) {
            noteList(
                showsEmptyPlaceholder: viewModel.showsMyNotesEmptyPlaceholder,
                systemImage: "list.bullet.clipboard",
                title: NotesFlowUILocalization.localized("notes.list.empty.myNotes.title"),
                description: NotesFlowUILocalization.localized("notes.list.empty.myNotes.message")
            ) {
                myNotesList
            }
                .tag(NoteListSegment.myNotes)
                .tabItem {
                    #if os(iOS)
                    Image(systemName: "list.bullet.clipboard")
                    #else
                    Text(NotesFlowUILocalization.localized("notes.list.segment.myNotes"))
                    #endif
                }

            noteList(
                showsEmptyPlaceholder: viewModel.showsSharedEmptyPlaceholder,
                systemImage: "rectangle.stack.badge.person.crop",
                title: NotesFlowUILocalization.localized("notes.list.empty.shared.title"),
                description: NotesFlowUILocalization.localized("notes.list.empty.shared.message")
            ) {
                sharedNotesList
            }
                .tag(NoteListSegment.shared)
                .tabItem {
                    #if os(iOS)
                    Image(systemName: "rectangle.stack.badge.person.crop")
                    #else
                    Text(NotesFlowUILocalization.localized("notes.list.segment.shared"))
                    #endif
                    
                }
        }
        .onChange(of: viewModel.selectedSegment) { _, segment in
            Task {
                switch segment {
                case .myNotes:
                    await viewModel.reloadSummaries()
                case .shared:
                    await viewModel.reloadSharedSummaries()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.reloadSummaries()
            }
        }
        .task {
            await viewModel.refresh()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(NotesFlowUILocalization.localized("notes.list.settings"))
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(NotesFlowUILocalization.localized("notes.list.settings"))
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createNote()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NotesFlowUILocalization.localized("notes.create.title"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
        .alert(
            NotesFlowUILocalization.localized("common.delete"),
            isPresented: Binding(
                get: { pendingDeleteSharedNoteID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteSharedNoteID = nil
                    }
                }
            ),
            presenting: pendingDeleteSharedNoteID
        ) { noteID in
            Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                Task {
                    await viewModel.deleteSharedNote(noteID: noteID)
                    pendingDeleteSharedNoteID = nil
                }
            }
            Button(NotesFlowUILocalization.localized("common.cancel"), role: .cancel) {
                pendingDeleteSharedNoteID = nil
            }
        } message: { _ in
            Text(NotesFlowUILocalization.localized("notes.shared.delete.confirmation"))
        }
    }
    
    @ViewBuilder
    private func noteList(
        showsEmptyPlaceholder: Bool,
        systemImage: String,
        title: String,
        description: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
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

            content()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if showsEmptyPlaceholder {
                EmptyPlaceholderView(
                    systemImage: systemImage,
                    title: title,
                    description: description
                )
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var myNotesList: some View {
        ForEach(viewModel.notes, id: \.noteID) { note in
            Group {
                HStack {
                    Text(note.title)
                    Spacer()
                    NoteSyncStatusLabel(syncState: note.syncState, displayStyle: .iconOnly)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
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

    @ViewBuilder
    private var sharedNotesList: some View {
        ForEach(viewModel.sharedNotes, id: \.noteID) { note in
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                Text(note.ownerEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.openSharedDetail(noteID: note.noteID)
            }
            .contextMenu {
                Button(NotesFlowUILocalization.localized("common.delete"), role: .destructive) {
                    pendingDeleteSharedNoteID = note.noteID
                }
            }
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

    func shareNote(noteID: UUID, recipientEmail: String, wrappedFEK: Data) async throws {
        _ = noteID
        _ = recipientEmail
        _ = wrappedFEK
        throw NoteRepositoryError.notSupported
    }

    func listSharedNotes() async throws -> [SharedNoteSummary] {
        []
    }

    func readSharedNote(noteID: UUID) async throws -> SharedNote {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

    func deleteSharedNote(noteID: UUID) async throws {
        _ = noteID
        throw NoteRepositoryError.notSupported
    }

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
