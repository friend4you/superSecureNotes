## ADDED Requirements

### Requirement: Note list shared segment local-first refresh

`DefaultNoteListViewModel` SHALL load shared summaries from `noteRepository.listSharedNotes()` after `noteSync.flushPending()` on refresh, matching the owned-notes refresh pattern. The Shared segment SHALL display locally stored shared summaries without requiring direct network calls from the ViewModel.

#### Scenario: Refresh loads shared notes after sync flush

- **WHEN** `refresh()` is called while the Shared segment is selected
- **THEN** `flushPending()` runs before `listSharedNotes()` and `sharedNotes` is updated from local storage

#### Scenario: Segment switch reloads local shared summaries

- **WHEN** the user selects the Shared segment
- **THEN** `reloadSharedSummaries()` reads from `listSharedNotes()` without invoking network APIs directly

### Requirement: Note list segmented control

`NoteListView` SHALL display a segmented control with segments `My Notes` and `Shared`. The selected segment SHALL determine which list data is shown.

#### Scenario: Default segment is My Notes

- **WHEN** `NoteListView` first appears
- **THEN** the `My Notes` segment is selected and owned notes are listed

#### Scenario: Shared segment shows shared summaries

- **WHEN** the user selects the `Shared` segment and shared rows exist locally
- **THEN** `listSharedNotes()` results are displayed with title and owner email

### Requirement: SharedNoteDetailView load from local repository

`DefaultSharedNoteDetailViewModel` SHALL load shared note content via `readSharedNote(noteID:)` on the local repository, decrypt using `unwrapSharedFEK` and `vaultSession.identityPrivateKey()`, and obtain `ownerEmail` from the local shared index row for that note ID. It SHALL NOT call `listSharedNotes()` during load solely to resolve owner email.

#### Scenario: Load decrypts shared note content

- **WHEN** `load()` succeeds for a shared note with cached or imported body
- **THEN** title and body are populated from the decrypted payload

#### Scenario: Owner email from local index

- **WHEN** the shared detail view renders after load
- **THEN** owner email comes from the local shared summary row for that note ID

#### Scenario: Load does not list all shared notes

- **WHEN** `load()` runs for a shared note detail
- **THEN** `listSharedNotes()` is not invoked as part of resolving owner email

### Requirement: SharedNoteDetailView read-only

`SharedNoteDetailView` SHALL NOT expose Save, Share, or editable title/body fields. Shared delete from the list context menu remains allowed.

#### Scenario: Fields are not editable

- **WHEN** the shared detail view is rendered
- **THEN** title and body are displayed as non-editable text and no Save toolbar button is present

## MODIFIED Requirements

### Requirement: NotesFlow does not manage storage lifecycle

`NotesFlow` ViewModels and views SHALL NOT call `NotesIndexStore.open`, `NotesIndexStore.close`, or any storage lifecycle API. Notes screens SHALL assume the notes index store was opened by the auth/app layer before navigation to the notes flow.

#### Scenario: Note list view model does not open index store

- **WHEN** `DefaultNoteListViewModel.refresh()` is called
- **THEN** only `noteRepository.listNotes()` or `noteRepository.listSharedNotes()` is invoked for the active segment; no index store lifecycle methods are called

#### Scenario: Create note view model does not open index store

- **WHEN** `DefaultCreateNoteViewModel.save()` is called
- **THEN** only `noteRepository.writeNote(_:)` is invoked; no index store lifecycle methods are called

#### Scenario: Detail note view model does not open index store

- **WHEN** `DefaultNoteDetailViewModel.load()` is called
- **THEN** only `noteRepository.readNote(noteID:)` is invoked; no index store lifecycle methods are called

#### Scenario: Shared detail view model does not open index store

- **WHEN** `DefaultSharedNoteDetailViewModel.load()` is called
- **THEN** only `noteRepository.readSharedNote(noteID:)` and local index lookup for owner email are used; no index store lifecycle methods are called
