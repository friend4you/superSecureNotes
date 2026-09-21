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

#if DEBUG
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
#endif
