## ADDED Requirements

### Requirement: SharedNoteSummary model

`NoteRepositoryProtocol` SHALL define a `SharedNoteSummary` struct that is `Sendable` and `Equatable` with fields: `noteID: UUID`, `title: String`, `updatedAt: UInt64`, `etag: String`, `ownerEmail: String`, `ownerID: UUID`, and `sharedAt: Date`.

#### Scenario: SharedNoteSummary is equatable

- **WHEN** two `SharedNoteSummary` values have identical fields
- **THEN** they are equal

### Requirement: SharedNote model

`NoteRepositoryProtocol` SHALL define a `SharedNote` struct that is `Sendable` and `Equatable` with fields: `noteID: UUID`, `metadata: NoteMetadata`, `recipientWrappedFEK: Data`, and `encryptedPayload: Data`.

#### Scenario: SharedNote carries download payload

- **WHEN** a `SharedNote` is constructed from a shared body import
- **THEN** it includes metadata, recipient-wrapped FEK bytes, and encrypted payload bytes

### Requirement: NoteRepository sharing methods

`NoteRepository` SHALL expose async methods: `shareNote(noteID:recipientEmail:wrappedFEK:)`, `listSharedNotes()`, `readSharedNote(noteID:)`, and `deleteSharedNote(noteID:)`. `listSharedNotes()` on `LocalNoteRepository` SHALL read the local `shared_notes` index. `readSharedNote(noteID:)` on `LocalNoteRepository` SHALL return a locally cached shared note when present and etag-valid; otherwise SHALL import via `GET /v1/notes/shared/{note_id}/body`. `shareNote` on `LocalNoteRepository` SHALL throw `NoteRepositoryError.notSupported`. `NetworkNoteRepository` SHALL implement network transport for sharing operations.

#### Scenario: List shared notes returns local summaries

- **WHEN** `LocalNoteRepository.listSharedNotes()` succeeds and shared rows exist locally
- **THEN** an array of `SharedNoteSummary` is returned from the local index with owner email and shared timestamp

#### Scenario: Read shared note uses split body endpoint on import

- **WHEN** `LocalNoteRepository.readSharedNote(noteID:)` requires a network import
- **THEN** the client uses `GET /v1/notes/shared/{note_id}/body` and does not call the monolithic `GET /v1/notes/shared/{note_id}` blob endpoint

#### Scenario: Local share note not supported

- **WHEN** `LocalNoteRepository.shareNote(noteID:recipientEmail:wrappedFEK:)` is called
- **THEN** `NoteRepositoryError.notSupported` is thrown

### Requirement: Shared notes index schema

`NotesIndexStore` SHALL persist a `shared_notes` table with columns: `note_id`, `title`, `updated_at`, `etag`, `owner_email`, `owner_id`, `shared_at`, and optional `body_etag` for cached body invalidation. The table SHALL be separate from the owned `notes` table.

#### Scenario: Shared row roundtrip preserves fields

- **WHEN** a shared index row is upserted and fetched by `note_id`
- **THEN** all column values match the written row including `body_etag` when present

#### Scenario: Owned and shared catalogs are independent

- **WHEN** the same UUID exists as an owned note and an incoming shared note
- **THEN** both rows may coexist because owned data lives in `notes` and shared summaries in `shared_notes`

### Requirement: Local shared note file layout

`LocalNoteRepository` SHALL persist shared note body SSNT wire bytes at `Application Support/superSecureNotes/shared/{noteID}/body` and shared attachment ciphertext at `shared/{noteID}/attachments/{attachmentID}`. Shared files SHALL NOT be stored under the owned `notes/{noteID}/` tree.

#### Scenario: Shared body file path

- **WHEN** a shared body import succeeds
- **THEN** `shared/{noteID}/body` contains the SSNT wire bytes from the shared body endpoint

#### Scenario: Shared attachments isolated from owned tree

- **WHEN** a shared attachment file is written locally
- **THEN** it is stored under `shared/{noteID}/attachments/` and not under `notes/{noteID}/attachments/`

### Requirement: LocalNoteRepository listSharedNotes from index

`LocalNoteRepository.listSharedNotes()` SHALL query the `shared_notes` table and return `[SharedNoteSummary]`. It SHALL NOT call the network directly.

#### Scenario: Local shared list returns empty when no shares

- **WHEN** the shared index contains no rows
- **THEN** `listSharedNotes()` returns an empty array

#### Scenario: Local shared list does not scan network

- **WHEN** `listSharedNotes()` is called while offline
- **THEN** locally cached shared summaries are returned without requiring network access

### Requirement: LocalNoteRepository deleteSharedNote local-first

`LocalNoteRepository.deleteSharedNote(noteID:)` SHALL remove the shared index row and `shared/{noteID}/` directory immediately and enqueue a remote delete for sync flush. It SHALL NOT require remote success before the note disappears from `listSharedNotes()`.

#### Scenario: Shared delete removes local index immediately

- **WHEN** `deleteSharedNote(noteID:)` succeeds locally
- **THEN** subsequent `listSharedNotes()` does not include that note ID

#### Scenario: Shared delete enqueues remote flush

- **WHEN** `deleteSharedNote(noteID:)` succeeds locally while offline
- **THEN** a pending remote shared delete remains queued for a later `flushPending()`

### Requirement: Network shared body read

`NetworkNoteRepository` / `NoteAPIClient` SHALL fetch shared note bodies via `GET /v1/notes/shared/{noteId}/body`, parsing `{ noteId, wrappedFek, body }` base64 fields into metadata and encrypted payload sections. Monolithic shared blob download SHALL NOT be used for new imports.

#### Scenario: Network shared body parses SSNT sections

- **WHEN** `GET /v1/notes/shared/{noteId}/body` returns a valid response
- **THEN** the client extracts recipient-wrapped FEK bytes and encrypted payload bytes from the decoded body wire blob

## MODIFIED Requirements

### Requirement: NoteRepository protocol

The module SHALL provide a `NoteRepository` protocol implemented by an `actor` with async CRUD methods: `listNotes()`, `readNote(noteID:)`, `writeNote(_:)`, and `deleteNote(noteID:)`, and sharing methods: `shareNote(noteID:recipientEmail:wrappedFEK:)`, `listSharedNotes()`, `readSharedNote(noteID:)`, and `deleteSharedNote(noteID:)`. The protocol SHALL NOT include storage lifecycle methods (`openDatabase`, `closeDatabase`, or equivalent). `LocalNoteRepository` and `NetworkNoteRepository` SHALL both conform to this protocol.

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

#### Scenario: List shared notes returns summaries

- **WHEN** `listSharedNotes()` succeeds on `LocalNoteRepository`
- **THEN** the returned array contains locally stored `SharedNoteSummary` values

#### Scenario: NoteRepository protocol has no lifecycle methods

- **WHEN** the `NoteRepository` protocol public API is inspected
- **THEN** it contains CRUD and sharing methods but no storage lifecycle methods
