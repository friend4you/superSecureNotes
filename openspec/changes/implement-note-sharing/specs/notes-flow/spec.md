## ADDED Requirements

### Requirement: Note list segmented control

`NoteListView` SHALL display a segmented control with segments `My Notes` and `Shared`. The selected segment SHALL determine which list data is shown.

#### Scenario: Default segment is My Notes

- **WHEN** `NoteListView` first appears
- **THEN** the `My Notes` segment is selected and owned notes are listed

#### Scenario: Shared segment shows shared summaries

- **WHEN** the user selects the `Shared` segment
- **THEN** `listSharedNotes()` results are displayed with title and owner email

### Requirement: NoteListViewModel shared notes loading

`DefaultNoteListViewModel` SHALL expose `selectedSegment`, `sharedNotes: [SharedNoteSummary]`, and load shared summaries when the Shared segment is active or on refresh. Tapping a shared note SHALL push `NotesRoute.sharedDetail(noteID:)`.

#### Scenario: Refresh loads shared notes when Shared segment selected

- **WHEN** `refresh()` is called while the Shared segment is selected
- **THEN** `listSharedNotes()` is invoked and `sharedNotes` is updated

#### Scenario: Open shared detail pushes shared route

- **WHEN** the user taps a shared note row
- **THEN** `navigator.push(NotesRoute.sharedDetail(noteID:))` is called

### Requirement: NotesRoute shared detail case

`NotesRoute` SHALL include `sharedDetail(noteID: UUID)` for read-only shared note screens.

#### Scenario: Shared detail route is registered

- **WHEN** `NotesNavigation.view(for: .sharedDetail(noteID:), deps:)` is called
- **THEN** a read-only shared detail view is produced

### Requirement: SharedNoteDetailView read-only

`NotesFlow` SHALL provide `SharedNoteDetailView` and `DefaultSharedNoteDetailViewModel` that load via `readSharedNote(noteID:)`, decrypt using `unwrapSharedFEK` and `vaultSession.identityPrivateKey()`, and display owner email, title, body, and attachments. The view SHALL NOT expose Save, Delete, Share, or editable title/body fields.

#### Scenario: Load decrypts shared note content

- **WHEN** `load()` succeeds for a shared note
- **THEN** title and body are populated from the decrypted payload

#### Scenario: Owner email is displayed

- **WHEN** the shared detail view is rendered after load
- **THEN** the owner email from the list summary is visible

#### Scenario: Fields are not editable

- **WHEN** the shared detail view is rendered
- **THEN** title and body are displayed as non-editable text and no Save toolbar button is present
