# Note Repository

## Purpose

Defines the `NoteRepository` protocol, local encrypted storage via `NotesIndexStore` and payload files, and network wire-format mapping.

## Requirements

### Requirement: NoteSyncState enum

The `NoteRepositoryProtocol` module SHALL define a `NoteSyncState` enum that is `Sendable` and `Equatable` with cases `pendingSync` and `synced`.

#### Scenario: NoteSyncState cases are equatable

- **WHEN** two `NoteSyncState.pendingSync` values are compared
- **THEN** they are equal

### Requirement: StoredNote model

The `NoteRepositoryProtocol` module SHALL define a `StoredNote` struct that is `Sendable` and `Equatable` with fields: `metadata: NoteMetadata` (from SecureCrypto), `wrappedFEK: Data`, `encryptedPayload: Data`, and `syncState: NoteSyncState`.

#### Scenario: StoredNote is equatable

- **WHEN** two `StoredNote` values with identical field values are compared
- **THEN** they are equal

### Requirement: NotesIndexStore actor

The `NoteRepository` target SHALL provide a `NotesIndexStore` actor that owns the SQLCipher-encrypted notes index database at `Application Support/superSecureNotes/notes/notes.db`. It SHALL expose `open(passphrase: Data)` and `close()` async methods. It SHALL expose `isOpen` indicating whether a database connection is active. It SHALL NOT be part of the `NoteRepository` protocol.

#### Scenario: open enables index queries

- **WHEN** `open(passphrase:)` succeeds
- **THEN** `isOpen` is `true` and index query methods succeed for valid inputs

#### Scenario: close disables index queries

- **WHEN** `close()` is called after a successful `open`
- **THEN** `isOpen` is `false` and subsequent index queries throw a not-open error

#### Scenario: Database file created on first open

- **WHEN** `open(passphrase:)` is called and no database file exists
- **THEN** `notes/notes.db` is created under `Application Support/superSecureNotes/`

#### Scenario: Database requires correct passphrase

- **WHEN** `notes.db` exists and `open` is called with an incorrect passphrase
- **THEN** `open` throws an error

### Requirement: NotesIndexStore schema

`NotesIndexStore` SHALL persist note index rows with columns: `note_id`, `title`, `created_at`, `updated_at`, `attachment_count`, `attachments_total_size`, `wrapped_fek`, and `sync_state`.

#### Scenario: Row roundtrip preserves fields

- **WHEN** a note index row is upserted and fetched by `note_id`
- **THEN** all column values match the written row

### Requirement: NoteRepositoryError databaseNotOpen case

The module SHALL add `databaseNotOpen` to `NoteRepositoryError`.

#### Scenario: databaseNotOpen is equatable

- **WHEN** two `NoteRepositoryError.databaseNotOpen` values are compared
- **THEN** they are equal

### Requirement: NoteRepository protocol

The module SHALL provide a `NoteRepository` protocol implemented by an `actor` with async CRUD methods only: `listNotes()`, `readNote(noteID:)`, `writeNote(_:)`, and `deleteNote(noteID:)`. The protocol SHALL NOT include storage lifecycle methods (`openDatabase`, `closeDatabase`, or equivalent). `readNote` SHALL return `StoredNote`. `writeNote` SHALL accept `StoredNote`. `listNotes()` SHALL return `[NoteSummary]`. `LocalNoteRepository` and `NetworkNoteRepository` SHALL both conform to this protocol.

#### Scenario: List notes returns summaries

- **WHEN** `listNotes()` succeeds
- **THEN** the returned array contains `NoteSummary` values with note ID, title, and updated timestamp

#### Scenario: Read note returns StoredNote

- **WHEN** `readNote(noteID:)` succeeds
- **THEN** the returned value is a `StoredNote` with metadata, wrapped FEK, encrypted payload, and sync state

#### Scenario: Write note stores structured note

- **WHEN** `writeNote(_:)` succeeds with a valid `StoredNote`
- **THEN** the note is persisted for subsequent `readNote(noteID:)`

#### Scenario: Delete note removes note

- **WHEN** `deleteNote(noteID:)` succeeds
- **THEN** the note is no longer retrievable via `readNote(noteID:)`

#### Scenario: NoteRepository protocol has no lifecycle methods

- **WHEN** the `NoteRepository` protocol public API is inspected
- **THEN** it contains only `listNotes`, `readNote`, `writeNote`, and `deleteNote`

### Requirement: LocalNoteRepository uses NotesIndexStore

`LocalNoteRepository` SHALL depend on an injected `NotesIndexStore` for metadata and `wrapped_fek` persistence. It SHALL NOT expose or implement storage lifecycle methods. CRUD methods SHALL throw `NoteRepositoryError.databaseNotOpen` when `NotesIndexStore.isOpen` is `false`.

#### Scenario: CRUD before index store open throws databaseNotOpen

- **WHEN** `listNotes()` is called while `NotesIndexStore` is not open
- **THEN** `NoteRepositoryError.databaseNotOpen` is thrown

#### Scenario: CRUD succeeds when index store is open

- **WHEN** `NotesIndexStore` is open and `writeNote` is called with a valid `StoredNote`
- **THEN** a subsequent `readNote(noteID:)` returns an equal `StoredNote`

### Requirement: LocalNoteRepository payload file storage

`LocalNoteRepository` SHALL persist encrypted payload bytes at `Application Support/superSecureNotes/notes/{noteID}/payload`. The payload file SHALL contain only encrypted payload bytes with no metadata or wrapped FEK.

#### Scenario: Write stores payload file without metadata header

- **WHEN** `writeNote` succeeds with a `StoredNote`
- **THEN** `notes/{noteID}/payload` contains bytes identical to `storedNote.encryptedPayload` with no SSNT metadata header

### Requirement: LocalNoteRepository write validation

#### Scenario: Write rejects empty encrypted payload

- **WHEN** `writeNote` is called with empty `encryptedPayload`
- **THEN** the call throws `NoteRepositoryError.validationError` without writing files

#### Scenario: New write persists sync state

- **WHEN** `writeNote` is called with `syncState: .pendingSync`
- **THEN** the stored index row has `sync_state` equal to `pendingSync`

### Requirement: LocalNoteRepository list notes from index store

`LocalNoteRepository.listNotes()` SHALL query `NotesIndexStore` and return `NoteSummary` entries. It SHALL NOT scan payload directories for metadata.

#### Scenario: List notes from index store

- **WHEN** one or more notes exist in the index store
- **THEN** `listNotes()` returns `NoteSummary` values with `noteID`, `title`, and `updatedAt` from index rows

#### Scenario: List returns empty when no notes

- **WHEN** the index store contains no note rows
- **THEN** `listNotes()` returns an empty array

### Requirement: LocalNoteRepository delete and corrupt note handling

#### Scenario: Delete removes index row and payload directory

- **WHEN** `deleteNote(noteID: id)` is called for an existing note
- **THEN** the index row is removed, `notes/{id}/` directory is removed, and subsequent `readNote` throws `noteNotFound`

#### Scenario: Read missing note throws noteNotFound

- **WHEN** `readNote(noteID:)` is called and no index row exists for that ID
- **THEN** `NoteRepositoryError.noteNotFound` is thrown

#### Scenario: Read incomplete note throws corruptNote

- **WHEN** `readNote(noteID:)` is called and an index row exists but the `payload` file is missing
- **THEN** `NoteRepositoryError.corruptNote` is thrown

#### Scenario: Payload without index row throws corruptNote

- **WHEN** `readNote(noteID:)` is called and a `payload` file exists but no index row exists
- **THEN** `NoteRepositoryError.corruptNote` is thrown

### Requirement: LocalNoteRepository atomic payload writes

`LocalNoteRepository` SHALL write the `payload` file to a temporary sibling directory and atomically replace the target note directory by rename.

#### Scenario: Atomic replace on update

- **WHEN** `writeNote` updates an existing note
- **THEN** the previous `payload` file is replaced atomically via directory rename

### Requirement: LocalNoteRepository does not perform crypto

`LocalNoteRepository` SHALL NOT encrypt, decrypt, wrap, or unwrap FEKs. It SHALL store `encryptedPayload` and `wrappedFEK` bytes as provided.

#### Scenario: Repository stores ciphertext without decrypting

- **WHEN** `writeNote` succeeds
- **THEN** the on-disk `payload` file and index `wrapped_fek` column contain bytes identical to the input `StoredNote`

### Requirement: No crypto parsing in repository

`NetworkNoteRepository` SHALL use `SecureCrypto` wire-format helpers only to map between `StoredNote` and opaque upload/download bytes. `LocalNoteRepository` SHALL NOT decrypt payloads or unwrap FEKs. Note payload bytes SHALL remain encrypted at the repository boundary.

#### Scenario: Local repository returns encrypted payload without decrypting

- **WHEN** `LocalNoteRepository.readNote(noteID:)` succeeds
- **THEN** the returned `encryptedPayload` is identical to the on-disk `payload` file bytes

### Requirement: NetworkNoteRepository StoredNote mapping

`NetworkNoteRepository` SHALL map `StoredNote` to wire-format `.note` blobs on write using `assembleNoteFile`, and map wire blobs to `StoredNote` on read using `parseNoteFile` with `syncState: .synced`. It SHALL NOT use `NotesIndexStore`.

#### Scenario: Network write assembles wire blob

- **WHEN** `writeNote` is called on `NetworkNoteRepository` with a `StoredNote`
- **THEN** the HTTP request body is a wire-format `.note` blob assembled from the stored note sections

#### Scenario: Network read parses wire blob

- **WHEN** `readNote` succeeds on `NetworkNoteRepository`
- **THEN** the returned `StoredNote` has sections parsed from the wire blob and `syncState` equal to `synced`
