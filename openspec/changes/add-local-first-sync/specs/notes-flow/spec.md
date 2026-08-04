## ADDED Requirements

### Requirement: Note list shows sync status

`NoteListView` SHALL display a sync status indicator for each visible note based on `NoteSummary.syncState`, distinguishing at least `pendingSync` from `synced`.

#### Scenario: Pending note shows pending indicator

- **WHEN** the list contains a note with `syncState: .pendingSync`
- **THEN** the row presents a pending sync indicator

#### Scenario: Synced note shows synced indicator

- **WHEN** the list contains a note with `syncState: .synced`
- **THEN** the row presents a synced indicator

### Requirement: Note detail shows sync status

`NoteDetailView` / `DefaultNoteDetailViewModel` SHALL expose the loaded note's `syncState` and the detail screen SHALL show whether the note is pending sync or synced.

#### Scenario: Detail shows pending after local edit

- **WHEN** a note is loaded or saved with `syncState: .pendingSync`
- **THEN** the detail UI indicates the note is pending sync

#### Scenario: Detail shows synced state

- **WHEN** a note is loaded with `syncState: .synced`
- **THEN** the detail UI indicates the note is synced

### Requirement: Note list refresh flushes sync

`DefaultNoteListViewModel.refresh()` SHALL request a pending sync flush (when a sync orchestrator is available) in addition to reloading notes from the local repository.

#### Scenario: Refresh triggers sync flush

- **WHEN** `refresh()` is called
- **THEN** pending sync flush is invoked and `listNotes()` is loaded into the list

## MODIFIED Requirements

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, current `syncState`, and save via `writeNote(_:)` with a `StoredNote`. ViewModels SHALL depend on `NoteRepository` for CRUD only. After a successful local save, the app MAY kick fire-and-forget sync outside the ViewModel or via an injected sync-flush dependency that does not block save success.

#### Scenario: Load decrypts note content

- **WHEN** `load()` is called for a stored note
- **THEN** `readNote` returns a `StoredNote`, the wrapped FEK is unwrapped and payload decrypted, and title and body fields are populated

#### Scenario: Save writes StoredNote with pendingSync

- **WHEN** `save()` is called with valid changes and non-empty title
- **THEN** a `StoredNote` with `syncState: .pendingSync` is written via `writeNote(_:)`

#### Scenario: Can save requires changes and title

- **WHEN** title is empty or there are no changes from loaded state
- **THEN** `canSave` is false

#### Scenario: Can save when title non-empty and dirty

- **WHEN** title is non-empty and fields differ from loaded state
- **THEN** `canSave` is true

#### Scenario: Load exposes sync state

- **WHEN** `load()` succeeds for a stored note
- **THEN** the view model exposes the note's `syncState` for the detail UI
