## 1. EmptyPlaceholderView

- [ ] 1.1 Write failing tests: `EmptyPlaceholderView` source uses `ContentUnavailableView` with `systemImage`, `title`, and `description` parameters and has no `Button` (`NotesFlowTests/EmptyPlaceholderViewTests.swift`)
- [ ] 1.2 Add `EmptyPlaceholderView` wrapping `ContentUnavailableView`; make tests pass

## 2. Empty copy localization

- [ ] 2.1 Write failing tests: catalog contains `notes.list.empty.myNotes.title`, `notes.list.empty.myNotes.message`, `notes.list.empty.shared.title`, and `notes.list.empty.shared.message` with non-empty English values (`NotesFlowTests/Localization/LocalizationTests.swift`)
- [ ] 2.2 Add the four keys to `Localizable.xcstrings` (My Notes: “No Notes” / “Create your first encrypted note.”; Shared: “No Shared Notes” / “Notes people share with you will show up here.”); make tests pass

## 3. View model empty visibility

- [ ] 3.1 Write failing tests: My Notes empty is true after `reloadSummaries()` returns `[]` while not loading; Shared empty is true after `reloadSharedSummaries()` returns `[]`; both false while `isLoading`, when `errorMessage` is set, when the segment has rows, and Shared empty is false before the first shared reload (`NotesFlowTests/DefaultNoteListViewModelTests.swift` and/or `DefaultNoteListViewModelSharedTests.swift`)
- [ ] 3.2 Add `hasLoadedMyNotes` / `hasLoadedSharedNotes` (set after each segment reload) and `showsMyNotesEmptyPlaceholder` / `showsSharedEmptyPlaceholder` on `NoteListViewModel` / `DefaultNoteListViewModel`; make tests pass

## 4. Note list overlay wiring

- [ ] 4.1 Write failing tests: `NoteListView` source overlays `EmptyPlaceholderView` gated by `showsMyNotesEmptyPlaceholder` and `showsSharedEmptyPlaceholder`; My Notes passes `list.bullet.clipboard` and my-notes empty keys; Shared passes `rectangle.stack.badge.person.crop` and shared empty keys; overlay uses `allowsHitTesting(false)`; placeholder is not inside either `ForEach` (`NotesFlowTests/NoteListViewTests.swift`)
- [ ] 4.2 Overlay `EmptyPlaceholderView` on each segment list with the matching symbol and localized copy; make tests pass

## 5. Integration verification

- [ ] 5.1 Run `NotesFlow` tests and fix any regressions in list, shared, or localization tests
