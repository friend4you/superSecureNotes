import Foundation
import NotesFlowRoutes
import SwiftUI

@MainActor
public enum NotesNavigation {
    @ViewBuilder
    public static func view(for route: NotesRoute, deps: any NotesDependencyProviding) -> some View {
        switch route {
        case .list:
            listView(deps: deps)
        case .detail(let noteID):
            detailView(noteID: noteID, deps: deps)
        case .create:
            createView(deps: deps)
        }
    }

    public static func listView(deps: any NotesDependencyProviding) -> NoteListView {
        NoteListView(viewModel: deps.makeNoteListViewModel())
    }

    public static func detailView(noteID: UUID, deps: any NotesDependencyProviding) -> NoteDetailView {
        NoteDetailView(viewModel: deps.makeNoteDetailViewModel(noteID: noteID))
    }

    public static func createView(deps: any NotesDependencyProviding) -> CreateNoteView {
        CreateNoteView(viewModel: deps.makeCreateNoteViewModel())
    }
}
