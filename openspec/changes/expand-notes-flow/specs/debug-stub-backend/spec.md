## ADDED Requirements

### Requirement: FileNoteRepository stub

The app target SHALL provide a DEBUG-only `FileNoteRepository` actor conforming to `NoteRepository`. It SHALL persist each note as `{noteID}.note` under an Application Support subdirectory (default `stub-notes/`). It SHALL read and write opaque `.note` blob `Data` without parsing or encryption.

#### Scenario: Write and read roundtrip

- **WHEN** `writeNote(noteID: id, data: blob)` is called with non-empty `Data`
- **THEN** a subsequent `readNote(noteID: id)` returns equal `Data`

#### Scenario: List notes from stored files

- **WHEN** one or more `.note` files exist in the stub directory
- **THEN** `listNotes()` returns `NoteSummary` entries parsed from each file's plaintext header via `NoteMetadata.fromNoteFile`

#### Scenario: Delete removes file

- **WHEN** `deleteNote(noteID: id)` is called for an existing note file
- **THEN** the file is removed and a subsequent `readNote` throws `noteNotFound`

#### Scenario: Read missing note throws

- **WHEN** `readNote(noteID:)` is called for a note with no file
- **THEN** `NoteRepositoryError.noteNotFound` is thrown

### Requirement: Stub backend selects FileNoteRepository

When `StubBackendConfiguration.isEnabled` is true in DEBUG, `AppDependencies` SHALL construct `FileNoteRepository` instead of `NetworkNoteRepository`. When stub mode is disabled, `AppDependencies` SHALL use `NetworkNoteRepository`.

#### Scenario: Stub mode uses file note repository

- **WHEN** the app launches in DEBUG with `-UseStubBackend`
- **THEN** `AppDependencies.noteRepository` is a `FileNoteRepository` instance

#### Scenario: Network mode uses network note repository

- **WHEN** the app launches in DEBUG without `-UseStubBackend`
- **THEN** `AppDependencies.noteRepository` is a `NetworkNoteRepository` instance
