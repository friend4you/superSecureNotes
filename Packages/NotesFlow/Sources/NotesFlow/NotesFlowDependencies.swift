import NavigationProtocol
import NotesFlowRoutes

@MainActor
public final class NotesFlowDependencies: NotesDependencyProviding {
    private let navigator: any Navigating

    public init(navigator: any Navigating) {
        self.navigator = navigator
    }
}
