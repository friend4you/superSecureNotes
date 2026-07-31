## MODIFIED Requirements

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, and save via `writeNote(_:)` with a `StoredNote`.

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

### Requirement: CreateNoteViewModel create flow

`NotesFlow` SHALL provide `CreateNoteViewModel` and `DefaultCreateNoteViewModel` with editable title and body, attachment collection, `canSave` (non-empty title and at least one field dirty), loading and error state, and `save()` that creates a new note with a generated UUID, encrypts content, writes a `StoredNote` with `syncState: .pendingSync` via `writeNote(_:)`, and pops.

#### Scenario: Save creates new note and pops

- **WHEN** `save()` is called with non-empty title
- **THEN** a new note ID is generated, a `StoredNote` is written via `writeNote(_:)`, and `navigator.pop()` is called

#### Scenario: Can save requires non-empty title and changes

- **WHEN** title is empty
- **THEN** `canSave` is false

#### Scenario: Can save with title and any content

- **WHEN** title is non-empty and title, body, or attachments differ from initial empty state
- **THEN** `canSave` is true
