import NotesFlowRoutes
import SwiftUI

@MainActor
public enum NotesNavigation {
    @ViewBuilder
    public static func view(for route: NotesRoute, deps: any NotesDependencyProviding) -> some View {
        switch route {
        case .list:
            listView(deps: deps)
        case .detail:
            EmptyView()
        case .create:
            EmptyView()
        }
    }

    public static func listView(deps: any NotesDependencyProviding) -> NoteListView {
        NoteListView(viewModel: deps.makeNoteListViewModel())
    }
}
