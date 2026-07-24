import NotesFlowRoutes
import SwiftUI

@MainActor
enum NotesNavigation {
    @ViewBuilder
    static func view(for route: NotesRoute, deps: any NotesDependencyProviding) -> some View {
        switch route {
        case .list:
            listView(deps: deps)
        }
    }

    static func listView(deps: any NotesDependencyProviding) -> NoteListView {
        _ = deps
        return NoteListView()
    }
}
