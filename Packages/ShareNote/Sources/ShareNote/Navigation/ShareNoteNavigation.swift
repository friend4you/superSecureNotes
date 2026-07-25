import Foundation
import ShareNoteRoutes
import SwiftUI

@MainActor
public enum ShareNoteNavigation {
    @ViewBuilder
    public static func view(for route: ShareNoteRoute, deps: any ShareNoteDependencyProviding) -> some View {
        switch route {
        case .share(let noteID):
            shareView(noteID: noteID, deps: deps)
        }
    }

    public static func shareView(noteID: UUID, deps: any ShareNoteDependencyProviding) -> ShareNoteView {
        ShareNoteView(viewModel: deps.makeShareNoteViewModel(noteID: noteID))
    }
}
