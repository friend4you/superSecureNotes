## ADDED Requirements

### Requirement: EmptyPlaceholderView parameterized empty chrome

`NotesFlow` SHALL provide `EmptyPlaceholderView` that accepts `systemImage`, `title`, and `description` and renders Apple empty-state chrome (symbol, title, and description). The view SHALL NOT include an action button and SHALL NOT encode My Notes vs Shared copy.

#### Scenario: Placeholder renders passed symbol and copy

- **WHEN** `EmptyPlaceholderView` is created with a system image name, title, and description
- **THEN** the view displays that symbol, title, and description

#### Scenario: Placeholder has no action button

- **WHEN** `EmptyPlaceholderView` is rendered
- **THEN** it has no button or other action control

### Requirement: Note list empty placeholder visibility

`DefaultNoteListViewModel` SHALL expose whether each segment should show the empty placeholder. My Notes empty SHALL be true only after owned summaries have loaded, `isLoading` is false, `errorMessage` is nil, and `notes` is empty. Shared empty SHALL be true only after shared summaries have loaded, `isLoading` is false, `errorMessage` is nil, and `sharedNotes` is empty. Until a segment has loaded at least once, its empty placeholder SHALL be false.

#### Scenario: My Notes empty after successful load with no notes

- **WHEN** `reloadSummaries()` succeeds with an empty array and `isLoading` is false
- **THEN** the My Notes empty placeholder flag is true

#### Scenario: Shared empty after successful load with no shared notes

- **WHEN** `reloadSharedSummaries()` succeeds with an empty array and `isLoading` is false
- **THEN** the Shared empty placeholder flag is true

#### Scenario: Empty hidden while loading

- **WHEN** `isLoading` is true
- **THEN** both empty placeholder flags are false

#### Scenario: Empty hidden when an error is present

- **WHEN** `errorMessage` is non-nil
- **THEN** both empty placeholder flags are false

#### Scenario: Empty hidden when the segment has rows

- **WHEN** owned or shared summaries contain at least one item
- **THEN** that segment’s empty placeholder flag is false

#### Scenario: Shared empty hidden before first shared load

- **WHEN** the Shared segment has never completed `reloadSharedSummaries()`
- **THEN** the Shared empty placeholder flag is false even if `sharedNotes` is empty

### Requirement: Note list shows EmptyPlaceholderView per segment

`NoteListView` SHALL overlay `EmptyPlaceholderView` on the My Notes list when the My Notes empty flag is true, and on the Shared list when the Shared empty flag is true. The placeholder SHALL NOT be a `List` row. Overlay content SHALL not block pull-to-refresh. My Notes SHALL pass `list.bullet.clipboard` and `notes.list.empty.myNotes.title` / `notes.list.empty.myNotes.message`. Shared SHALL pass `rectangle.stack.badge.person.crop` and `notes.list.empty.shared.title` / `notes.list.empty.shared.message`.

#### Scenario: My Notes empty uses clipboard symbol and my-notes copy

- **WHEN** the My Notes empty placeholder is shown
- **THEN** `EmptyPlaceholderView` is given `list.bullet.clipboard` and the My Notes empty localization keys

#### Scenario: Shared empty uses shared-stack symbol and shared copy

- **WHEN** the Shared empty placeholder is shown
- **THEN** `EmptyPlaceholderView` is given `rectangle.stack.badge.person.crop` and the Shared empty localization keys

#### Scenario: Placeholder is not a list row

- **WHEN** an empty placeholder is shown
- **THEN** it is overlaid on the list, not placed inside the list’s `ForEach` content
