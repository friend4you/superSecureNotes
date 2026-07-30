## ADDED Requirements

### Requirement: NoteRepositoryError corruptNote case

The module SHALL add `corruptNote` to `NoteRepositoryError` for incomplete or inconsistent local note storage.

#### Scenario: corruptNote is equatable

- **WHEN** two `NoteRepositoryError.corruptNote` values are compared
- **THEN** they are equal

### Requirement: LocalNoteRepository actor

The `NoteRepository` target SHALL provide a `LocalNoteRepository` actor conforming to `NoteRepository`. It SHALL persist notes under `Application Support/superSecureNotes/notes/{noteID}/` with files named `note` (local note body: metadata + encrypted payload) and `fek` (raw wrapped FEK bytes). It SHALL exclude the storage directory from iCloud backup.

#### Scenario: Write and read roundtrip via wire blob

- **WHEN** `writeNote(noteID: id, data: wireBlob)` is called with a valid wire-format `.note` blob whose metadata `noteID` matches `id`
- **THEN** a subsequent `readNote(noteID: id)` returns a wire blob equal to `wireBlob`

#### Scenario: Write rejects noteID mismatch

- **WHEN** `writeNote(noteID: id, data: wireBlob)` is called with a wire blob whose metadata `noteID` does not match `id`
- **THEN** the call throws `NoteRepositoryError.validationError` without writing files

#### Scenario: Write rejects empty data

- **WHEN** `writeNote(noteID:data:)` is called with empty `Data`
- **THEN** the call throws `NoteRepositoryError.validationError` without writing files

#### Scenario: List notes from stored directories

- **WHEN** one or more note directories exist under the notes storage root
- **THEN** `listNotes()` returns `NoteSummary` entries parsed from each directory's `note` file plaintext metadata

#### Scenario: Delete removes note directory

- **WHEN** `deleteNote(noteID: id)` is called for an existing note
- **THEN** the `{id}/` directory is removed and a subsequent `readNote` throws `noteNotFound`

#### Scenario: Read missing note throws noteNotFound

- **WHEN** `readNote(noteID:)` is called and no directory exists for that ID
- **THEN** `NoteRepositoryError.noteNotFound` is thrown

#### Scenario: Read incomplete note throws corruptNote

- **WHEN** `readNote(noteID:)` is called and the note directory exists but only one of `note` or `fek` is present
- **THEN** `NoteRepositoryError.corruptNote` is thrown

### Requirement: LocalNoteRepository atomic writes

`LocalNoteRepository` SHALL write `note` and `fek` to a temporary sibling directory and atomically replace the target note directory by rename. A failed write SHALL NOT leave a note directory with only one of the two files.

#### Scenario: Atomic replace on update

- **WHEN** `writeNote` updates an existing note
- **THEN** the previous `note` and `fek` files are replaced atomically via directory rename

### Requirement: LocalNoteRepository does not perform crypto

`LocalNoteRepository` SHALL treat wire-format blobs as opaque at the persistence boundary except for split/reassemble via `SecureCrypto` helpers. It SHALL NOT encrypt, decrypt, or unwrap FEKs.

#### Scenario: Repository stores split sections without decrypting payload

- **WHEN** `writeNote` succeeds
- **THEN** the on-disk `note` file contains encrypted payload bytes identical to the wire blob's payload section

## MODIFIED Requirements

### Requirement: NoteRepository protocol

The module SHALL provide a `NoteRepository` protocol implemented by an `actor` with async methods: `listNotes()`, `readNote(noteID:)`, `writeNote(noteID:data:)`, and `deleteNote(noteID:)`. Read and write methods for note content SHALL use raw `Data` (opaque wire-format `.note` bytes at the API boundary). `listNotes()` SHALL return `[NoteSummary]`. `LocalNoteRepository` and `NetworkNoteRepository` SHALL both conform to this protocol.

#### Scenario: List notes returns summaries

- **WHEN** `listNotes()` succeeds
- **THEN** the returned array contains `NoteSummary` values with note ID, title, and updated timestamp

#### Scenario: Read note returns note blob bytes

- **WHEN** `readNote(noteID:)` succeeds
- **THEN** the returned `Data` is a wire-format `.note` blob

#### Scenario: Write note stores note blob bytes

- **WHEN** `writeNote(noteID:data:)` succeeds with non-empty wire-format note bytes
- **THEN** the note is persisted for subsequent `readNote(noteID:)`

#### Scenario: Delete note removes note

- **WHEN** `deleteNote(noteID:)` succeeds
- **THEN** the note is no longer retrievable via `readNote(noteID:)`

### Requirement: No crypto parsing in repository

The `NetworkNoteRepository` SHALL NOT parse, validate, or serialize `NoteMetadata` or `NoteFileSections` structures. `LocalNoteRepository` MAY use `SecureCrypto` split/reassemble and local body parse helpers solely to map between wire-format blobs and on-disk split layout. Note payload bytes SHALL remain encrypted at the repository boundary.

#### Scenario: Network repository returns raw bytes without parsing

- **WHEN** `NetworkNoteRepository.readNote(noteID:)` succeeds
- **THEN** the returned value is the raw response body with no `NoteMetadata` parsing performed by the repository
