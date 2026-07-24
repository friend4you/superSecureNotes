import Navigation
import NotesFlowRoutes
import SwiftUI

extension RouteRegistry {
    public func registerNotesRoutes(deps: any NotesDependencyProviding) {
        register(NotesRoute.self) { route in
            AnyView(NotesNavigation.view(for: route, deps: deps))
        }
    }
}
