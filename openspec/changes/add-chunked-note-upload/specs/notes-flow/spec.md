## ADDED Requirements

### Requirement: Sync on create save

`DefaultCreateNoteViewModel` SHALL schedule a non-blocking pending sync flush immediately after a successful local `writeNote(_:)` and before or after navigation pop, without awaiting upload completion.

#### Scenario: Create save schedules background sync

- **WHEN** `DefaultCreateNoteViewModel.save()` successfully writes a new note locally
- **THEN** a sync flush is scheduled in the background and save completion is not blocked on network upload

### Requirement: Sync on detail save

`DefaultNoteDetailViewModel` SHALL schedule a non-blocking pending sync flush immediately after a successful local `writeNote(_:)` without awaiting upload completion.

#### Scenario: Detail save schedules background sync

- **WHEN** `DefaultNoteDetailViewModel.save()` successfully writes an edited note locally
- **THEN** a sync flush is scheduled in the background and save completion is not blocked on network upload

### Requirement: List UI updates on sync outcome

`DefaultNoteListViewModel` SHALL subscribe to note sync outcome events and reload or patch list summaries so a note row transitions from pending to synced when background upload succeeds, without requiring pull-to-refresh.

#### Scenario: List shows synced after background upload

- **WHEN** a note row is visible with `syncState: .pendingSync` and a successful sync outcome arrives for that note ID
- **THEN** the list UI presents the synced indicator for that row

#### Scenario: List shows new note after create

- **WHEN** the user saves a new note and returns to the note list
- **THEN** the new note appears in the list with a pending sync indicator before upload completes

### Requirement: Detail UI updates on sync outcome

`DefaultNoteDetailViewModel` SHALL subscribe to note sync outcome events for its note ID and update exposed `syncState` when background upload succeeds, without requiring a manual reload.

#### Scenario: Detail shows synced after background upload

- **WHEN** the detail screen shows `syncState: .pendingSync` and a successful sync outcome arrives for the same note ID
- **THEN** the detail UI presents the synced indicator

## MODIFIED Requirements

### Requirement: CreateNoteViewModel create flow

`NotesFlow` SHALL provide `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with editable title and body, attachment collection, `canSave` (non-empty title and at least one field dirty), loading and error state, and `save()` that creates a new note with a generated UUID, encrypts content, writes a `StoredNote` with `syncState: .pendingSync` via `writeNote(_:)`, schedules background sync flush, and pops.

#### Scenario: Save creates new note and pops

- **WHEN** `save()` is called with non-empty title
- **THEN** a new note ID is generated, a `StoredNote` is written via `writeNote(_:)`, background sync is scheduled, and `navigator.pop()` is called

#### Scenario: Can save requires non-empty title and changes

- **WHEN** title is empty
- **THEN** `canSave` is false

#### Scenario: Can save with title and any content

- **WHEN** title is non-empty and title, body, or attachments differ from initial empty state
- **THEN** `canSave` is true

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, current `syncState`, and save via `writeNote(_:)` with a `StoredNote`. ViewModels SHALL depend on `NoteRepository` for CRUD and MAY depend on an injected sync-scheduling type for fire-and-forget flush after save.

#### Scenario: Load decrypts note content

- **WHEN** `load()` is called for a stored note
- **THEN** `readNote` returns a `StoredNote`, the wrapped FEK is unwrapped and payload decrypted, and title and body fields are populated

#### Scenario: Save writes StoredNote with pendingSync

- **WHEN** `save()` is called with valid changes and non-empty title
- **THEN** a `StoredNote` with `syncState: .pendingSync` is written via `writeNote(_:)` and background sync is scheduled

#### Scenario: Can save requires changes and title

- **WHEN** title is empty or there are no changes from loaded state
- **THEN** `canSave` is false

#### Scenario: Can save when title non-empty and dirty

- **WHEN** title is non-empty and fields differ from loaded state
- **THEN** `canSave` is true

#### Scenario: Load exposes sync state

- **WHEN** `load()` succeeds for a stored note
- **THEN** the view model exposes the note's `syncState` for the detail UI
