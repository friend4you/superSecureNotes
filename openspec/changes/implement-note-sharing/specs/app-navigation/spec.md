## ADDED Requirements

### Requirement: ShareNote dependencies wired in app composition

`AppComposition` SHALL construct `ShareNoteDependencies` with `Navigating`, `NoteRepository`, `VaultRepository`, and `VaultSessionProtocol` instances shared with the rest of the app.

#### Scenario: Share dependencies use shared repositories

- **WHEN** `AppComposition` is initialized
- **THEN** `shareNoteDependencies` receives the same `noteRepository` and `vaultRepository` used elsewhere in the app

### Requirement: NotesFlow receives sharing-capable note repository

`NotesFlowDependencies` SHALL receive a `NoteRepository` that implements `listSharedNotes()` and `readSharedNote(noteID:)` so shared list and detail screens function in network mode.

#### Scenario: Notes flow can list shared notes

- **WHEN** `DefaultNoteListViewModel` refreshes the Shared segment
- **THEN** the injected `noteRepository` supports `listSharedNotes()`
