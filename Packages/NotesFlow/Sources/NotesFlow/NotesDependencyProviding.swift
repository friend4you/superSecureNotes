import Foundation

@MainActor
public protocol NotesDependencyProviding: AnyObject {
    func makeNoteListViewModel() -> DefaultNoteListViewModel
    func makeNoteDetailViewModel(noteID: UUID) -> DefaultNoteDetailViewModel
    func makeSharedNoteDetailViewModel(noteID: UUID) -> DefaultSharedNoteDetailViewModel
    func makeCreateNoteViewModel() -> DefaultCreateNoteViewModel
}
