import Foundation
import NavigationProtocol

@MainActor
public final class ShareNoteDependencies: ShareNoteDependencyProviding {
    private let navigator: any Navigating

    public init(navigator: any Navigating) {
        self.navigator = navigator
    }

    public func makeShareNoteViewModel(noteID: UUID) -> DefaultShareNoteViewModel {
        DefaultShareNoteViewModel(noteID: noteID, navigator: navigator)
    }
}
