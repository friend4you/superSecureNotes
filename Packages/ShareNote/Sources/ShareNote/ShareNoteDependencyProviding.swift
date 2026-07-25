import Foundation

@MainActor
public protocol ShareNoteDependencyProviding: AnyObject {
    func makeShareNoteViewModel(noteID: UUID) -> DefaultShareNoteViewModel
}
