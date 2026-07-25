@MainActor
public protocol NotesDependencyProviding: AnyObject {
    func makeNoteListViewModel() -> DefaultNoteListViewModel
}
