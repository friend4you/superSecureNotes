## ADDED Requirements

### Requirement: Attachment download progress UI

`NoteDetailView` and `SharedNoteDetailView` SHALL show per-attachment download progress (e.g. progress indicator per row) when hydration is active for that attachment. Progress SHALL reflect bytes received over total size from the sync layer.

#### Scenario: Detail shows progress for downloading attachment

- **WHEN** hydration reports partial progress for attachment id A
- **THEN** the row for attachment A shows a visible progress state

#### Scenario: Completed attachment hides progress

- **WHEN** hydration reports completion for attachment id A
- **THEN** the row for attachment A shows normal preview state without progress indicator

### Requirement: Attachment row retry

When an attachment download fails, the detail attachments section SHALL offer retry for that row only.

#### Scenario: Retry failed attachment row

- **WHEN** the user taps retry on a failed attachment row
- **THEN** hydration retries download for that attachment id only

### Requirement: Fast detail open from body

`DefaultNoteDetailViewModel` and `DefaultSharedNoteDetailViewModel` SHALL populate title and body as soon as body decrypt completes without waiting for attachment file downloads. Attachment filenames from the v2 index SHALL appear immediately; file preview SHALL wait for local ciphertext.

#### Scenario: Body visible before attachments downloaded

- **WHEN** body decrypt completes and attachments are still downloading
- **THEN** title and body text are shown and attachment rows show filenames with progress

## MODIFIED Requirements

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, and save via `writeNote(_:)` with a `StoredNote`. ViewModels SHALL depend on `NoteRepository` for CRUD only. `canSave` SHALL be false while `syncState` is not `synced` (Save disabled only; fields remain editable). ViewModels SHALL subscribe to attachment hydration progress for remote/cold opens.

#### Scenario: Load decrypts note content

- **WHEN** `load()` is called for a stored note
- **THEN** `readNote` returns a `StoredNote`, the wrapped FEK is unwrapped and payload decrypted, and title and body fields are populated

#### Scenario: Save writes StoredNote with pendingSync

- **WHEN** `save()` is called with valid changes, non-empty title, and `syncState` is `synced`
- **THEN** a `StoredNote` with `syncState: .pendingSync` is written via `writeNote(_:)` and `scheduleFlush()` is invoked

#### Scenario: Can save requires changes and title

- **WHEN** title is empty or there are no changes from loaded state
- **THEN** `canSave` is false

#### Scenario: Can save when title non-empty and dirty

- **WHEN** title is non-empty, fields differ from loaded state, and `syncState` is `synced`
- **THEN** `canSave` is true

#### Scenario: Can save false while pending sync

- **WHEN** `syncState` is `pendingSync`
- **THEN** `canSave` is false even if title is non-empty and fields are dirty

### Requirement: CreateNoteViewModel create flow

`NotesFlow` SHALL provide `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with editable title and body, attachment collection, `canSave` (non-empty title, at least one field dirty, and sync not blocking), loading and error state, and `save()` that creates a new note with generated UUIDs for note and attachments, writes split local storage with `syncState: .pendingSync`, invokes `scheduleFlush()`, and pops. First save SHALL wait until all local body and attachment parts exist before upload begins.

#### Scenario: Save creates new note and pops

- **WHEN** `save()` is called with non-empty title
- **THEN** a new note ID is generated, split local note is written via `writeNote(_:)`, `scheduleFlush()` is called, and `navigator.pop()` is called

#### Scenario: Can save requires non-empty title and changes

- **WHEN** title is empty
- **THEN** `canSave` is false

#### Scenario: Can save with title and any content

- **WHEN** title is non-empty and title, body, or attachments differ from initial empty state and no sync block applies
- **THEN** `canSave` is true
