# Notes Flow

## Purpose

Defines notes UI view models and their interaction with `NoteRepository` for CRUD operations.

## Requirements

### Requirement: NotesFlow does not manage storage lifecycle

`NotesFlow` ViewModels and views SHALL NOT call `NotesIndexStore.open`, `NotesIndexStore.close`, or any storage lifecycle API. Notes screens SHALL assume the notes index store was opened by the auth/app layer before navigation to the notes flow.

#### Scenario: Note list view model does not open index store

- **WHEN** `DefaultNoteListViewModel.refresh()` is called
- **THEN** only `noteRepository.listNotes()` is invoked; no index store lifecycle methods are called

#### Scenario: Create note view model does not open index store

- **WHEN** `DefaultCreateNoteViewModel.save()` is called
- **THEN** only `noteRepository.writeNote(_:)` is invoked; no index store lifecycle methods are called

#### Scenario: Detail note view model does not open index store

- **WHEN** `DefaultNoteDetailViewModel.load()` is called
- **THEN** only `noteRepository.readNote(noteID:)` is invoked; no index store lifecycle methods are called

### Requirement: NoteDetailViewModel load and save

`NotesFlow` SHALL provide `NoteDetailViewModel` and `DefaultNoteDetailViewModel` that load a note by ID, decrypt content using `VaultSession.udk()` and `SecureCrypto` note APIs, expose editable title and body strings, attachment filename list, `hasChanges`, `canSave`, loading and error state, and save via `writeNote(_:)` with a `StoredNote`. ViewModels SHALL depend on `NoteRepository` for CRUD only.

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
