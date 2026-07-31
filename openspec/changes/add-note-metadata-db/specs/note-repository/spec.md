## ADDED Requirements

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

### Requirement: NoteRepository database lifecycle

The `NoteRepository` protocol SHALL provide `openDatabase(passphrase: Data)` and `closeDatabase()` async methods. `openDatabase` SHALL open a SQLCipher-encrypted database using the provided passphrase. `closeDatabase` SHALL close the database connection. All note CRUD methods SHALL require an open database.

#### Scenario: openDatabase enables CRUD

- **WHEN** `openDatabase(passphrase:)` succeeds
- **THEN** subsequent `listNotes()`, `readNote`, `writeNote`, and `deleteNote` calls succeed for valid inputs

#### Scenario: CRUD before open throws databaseNotOpen

- **WHEN** `listNotes()` is called before `openDatabase`
- **THEN** `NoteRepositoryError.databaseNotOpen` is thrown

#### Scenario: closeDatabase prevents CRUD

- **WHEN** `closeDatabase()` is called after a successful `openDatabase`
- **THEN** subsequent `listNotes()` throws `NoteRepositoryError.databaseNotOpen`

### Requirement: NoteRepositoryError databaseNotOpen case

The module SHALL add `databaseNotOpen` to `NoteRepositoryError`.

#### Scenario: databaseNotOpen is equatable

- **WHEN** two `NoteRepositoryError.databaseNotOpen` values are compared
- **THEN** they are equal

### Requirement: LocalNoteRepository SQLCipher database

`LocalNoteRepository` SHALL persist note metadata and `wrapped_fek` in `Application Support/superSecureNotes/notes.db` using GRDB with SQLCipher encryption. The database SHALL be unreadable without the passphrase provided to `openDatabase`. Metadata columns SHALL include: `note_id`, `title`, `created_at`, `updated_at`, `attachment_count`, `attachments_total_size`, `wrapped_fek`, and `sync_state`.

#### Scenario: Database file created on first open

- **WHEN** `openDatabase(passphrase:)` is called and no database file exists
- **THEN** `notes.db` is created under `Application Support/superSecureNotes/`

#### Scenario: Database requires passphrase to read

- **WHEN** `notes.db` exists and is opened with an incorrect passphrase
- **THEN** `openDatabase` throws an error

### Requirement: LocalNoteRepository payload file storage

`LocalNoteRepository` SHALL persist encrypted payload bytes at `Application Support/superSecureNotes/notes/{noteID}/payload`. The payload file SHALL contain only encrypted payload bytes with no metadata or wrapped FEK.

#### Scenario: Write stores payload file without metadata header

- **WHEN** `writeNote` succeeds with a `StoredNote`
- **THEN** `notes/{noteID}/payload` contains bytes identical to `storedNote.encryptedPayload` with no SSNT metadata header

### Requirement: LocalNoteRepository write and read roundtrip

#### Scenario: Write and read roundtrip via StoredNote

- **WHEN** `writeNote` is called with a valid `StoredNote` whose `metadata.noteID` matches the note being stored
- **THEN** a subsequent `readNote(noteID:)` returns a `StoredNote` equal to the written value

#### Scenario: Write rejects noteID mismatch

- **WHEN** `writeNote` is called with a `StoredNote` whose `metadata.noteID` does not match an existing row's ID on update
- **THEN** the call throws `NoteRepositoryError.validationError` without corrupting storage

#### Scenario: Write rejects empty encrypted payload

- **WHEN** `writeNote` is called with empty `encryptedPayload`
- **THEN** the call throws `NoteRepositoryError.validationError` without writing files

#### Scenario: New write defaults sync state to pendingSync

- **WHEN** `writeNote` is called with `syncState: .pendingSync`
- **THEN** the stored row has `sync_state` equal to `pendingSync`

### Requirement: LocalNoteRepository list notes from database

`LocalNoteRepository.listNotes()` SHALL query the database and return `NoteSummary` entries. It SHALL NOT scan note directories or read payload files.

#### Scenario: List notes from database

- **WHEN** one or more notes exist in the database
- **THEN** `listNotes()` returns `NoteSummary` values with `noteID`, `title`, and `updatedAt` from database rows

#### Scenario: List returns empty when no notes

- **WHEN** the database contains no note rows
- **THEN** `listNotes()` returns an empty array

### Requirement: LocalNoteRepository delete

#### Scenario: Delete removes database row and payload directory

- **WHEN** `deleteNote(noteID: id)` is called for an existing note
- **THEN** the database row is removed, `notes/{id}/` directory is removed, and subsequent `readNote` throws `noteNotFound`

#### Scenario: Read missing note throws noteNotFound

- **WHEN** `readNote(noteID:)` is called and no database row exists for that ID
- **THEN** `NoteRepositoryError.noteNotFound` is thrown

#### Scenario: Read incomplete note throws corruptNote

- **WHEN** `readNote(noteID:)` is called and a database row exists but the `payload` file is missing
- **THEN** `NoteRepositoryError.corruptNote` is thrown

#### Scenario: Payload without database row throws corruptNote

- **WHEN** `readNote(noteID:)` is called and a `payload` file exists but no database row exists
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
- **THEN** the on-disk `payload` file and database `wrapped_fek` column contain bytes identical to the input `StoredNote`

### Requirement: NetworkNoteRepository database lifecycle no-op

`NetworkNoteRepository.openDatabase` and `closeDatabase` SHALL complete without error and without side effects.

#### Scenario: Network repository open is no-op

- **WHEN** `openDatabase(passphrase:)` is called on `NetworkNoteRepository`
- **THEN** the call completes without error

### Requirement: NetworkNoteRepository StoredNote mapping

`NetworkNoteRepository` SHALL map `StoredNote` to wire-format `.note` blobs on write using `assembleNoteFile`, and map wire blobs to `StoredNote` on read using `parseNoteFile` with `syncState: .synced`.

#### Scenario: Network write assembles wire blob

- **WHEN** `writeNote` is called on `NetworkNoteRepository` with a `StoredNote`
- **THEN** the HTTP request body is a wire-format `.note` blob assembled from the stored note sections

#### Scenario: Network read parses wire blob

- **WHEN** `readNote` succeeds on `NetworkNoteRepository`
- **THEN** the returned `StoredNote` has sections parsed from the wire blob and `syncState` equal to `synced`

## MODIFIED Requirements

### Requirement: NoteRepository protocol

The module SHALL provide a `NoteRepository` protocol implemented by an `actor` with async methods: `openDatabase(passphrase:)`, `closeDatabase()`, `listNotes()`, `readNote(noteID:)`, `writeNote(_:)`, and `deleteNote(noteID:)`. `readNote` SHALL return `StoredNote`. `writeNote` SHALL accept `StoredNote`. `listNotes()` SHALL return `[NoteSummary]`. `LocalNoteRepository` and `NetworkNoteRepository` SHALL both conform to this protocol.

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

### Requirement: No crypto parsing in repository

`NetworkNoteRepository` SHALL use `SecureCrypto` wire-format helpers only to map between `StoredNote` and opaque upload/download bytes. `LocalNoteRepository` SHALL NOT decrypt payloads or unwrap FEKs. Note payload bytes SHALL remain encrypted at the repository boundary.

#### Scenario: Local repository returns encrypted payload without decrypting

- **WHEN** `LocalNoteRepository.readNote(noteID:)` succeeds
- **THEN** the returned `encryptedPayload` is identical to the on-disk `payload` file bytes

## REMOVED Requirements

### Requirement: LocalNoteRepository split note and fek files

**Reason**: Replaced by SQLCipher database for metadata and wrapped FEK, with per-note `payload` file for encrypted content only.

**Migration**: Wipe app data; no automatic migration from `note` + `fek` layout.

#### Scenario: Old layout is not read

- **WHEN** only legacy `note` and `fek` files exist under `notes/{uuid}/`
- **THEN** `listNotes()` returns an empty array and `readNote` throws `noteNotFound`
