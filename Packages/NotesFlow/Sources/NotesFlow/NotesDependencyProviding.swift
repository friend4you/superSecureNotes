import Foundation

@MainActor
public protocol NotesDependencyProviding: AnyObject {
    func makeNoteListViewModel() -> DefaultNoteListViewModel
    func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel
    func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel
}
