import Foundation
import NavigationProtocol
import Observation

@MainActor
public protocol ShareNoteViewModel: Observable {
    var noteID: UUID { get }
    func dismiss()
}

@MainActor
@Observable
public final class DefaultShareNoteViewModel: ShareNoteViewModel {
    public let noteID: UUID
    private let navigator: any Navigating

    public init(noteID: UUID, navigator: any Navigating) {
        self.noteID = noteID
        self.navigator = navigator
    }

    public func dismiss() {
        navigator.pop()
    }
}
