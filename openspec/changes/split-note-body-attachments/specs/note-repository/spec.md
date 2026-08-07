## ADDED Requirements

### Requirement: Local split note file layout

`LocalNoteRepository` SHALL persist each note under `Application Support/superSecureNotes/notes/{noteID}/` with a `body` file containing SSNT wire bytes (metadata, wrapped FEK, encrypted payload) and an `attachments/` subdirectory containing one file per attachment id with encrypted attachment ciphertext bytes.

#### Scenario: Write stores body and attachment files

- **WHEN** `writeNote` succeeds for a note with two attachments
- **THEN** `notes/{noteID}/body` exists, `notes/{noteID}/attachments/{id}` exists for each attachment, and ciphertext bytes match the input

#### Scenario: Read assembles StoredNote from split files

- **WHEN** `readNote(noteID:)` succeeds for a split note
- **THEN** the returned `StoredNote` has metadata and wrapped FEK from the body file and encrypted payload from the body file ciphertext section

### Requirement: NotesIndexStore attachment rows

`NotesIndexStore` SHALL persist an `attachments` table keyed by `(note_id, attachment_id)` with columns including `etag`, `size_bytes`, and `sync_state`. Note rows SHALL include `body_etag` (or equivalent) for remote body divergence checks.

#### Scenario: Attachment row roundtrip

- **WHEN** an attachment row is upserted and fetched by note id and attachment id
- **THEN** etag, size, and sync state match the written values

### Requirement: Network body and attachment API mapping

`NetworkNoteRepository` SHALL upload and download notes using `GET/PUT /v1/notes/{noteId}/body` for SSNT body bytes and `GET/PUT/DELETE /v1/notes/{noteId}/attachments/{attachmentId}` for attachment ciphertext. It SHALL list attachment manifests via `GET /v1/notes/{noteId}/attachments`. Upload `contentType` SHALL be `application/octet-stream`. It SHALL NOT use monolithic `PUT/GET /v1/notes/{noteId}` for note content.

#### Scenario: Upload body uses body endpoint

- **WHEN** a note body is uploaded to the network repository
- **THEN** the client sends `PUT /v1/notes/{noteId}/body` with SSNT wire bytes

#### Scenario: Upload attachment uses attachment endpoint

- **WHEN** an attachment is uploaded
- **THEN** the client sends `PUT /v1/notes/{noteId}/attachments/{attachmentId}` with encrypted attachment bytes and `application/octet-stream` content type

#### Scenario: Download attachment by id

- **WHEN** an attachment is downloaded
- **THEN** the client calls `GET /v1/notes/{noteId}/attachments/{attachmentId}` and returns ciphertext bytes

### Requirement: Multi-part note sync upload

`LocalFirstNoteSyncService` SHALL upload pending notes by PUT body first, then PUT (or chunked upload) each pending attachment, then DELETE removed attachments. A note SHALL remain `pendingSync` until all parts succeed. On etag conflict or partial failure, the service SHALL retry upload from local state (local wins).

#### Scenario: Note synced only after all parts upload

- **WHEN** body upload succeeds and one attachment upload is still pending
- **THEN** the note index row remains `pendingSync`

#### Scenario: All parts succeed marks synced

- **WHEN** body and all attachments upload successfully
- **THEN** the note index row is `synced` and a success `NoteSyncOutcome` is emitted

### Requirement: Attachment chunked upload sessions

Attachment uploads larger than `NoteUploadSizeThreshold` SHALL use `POST/PUT/POST complete` under `/v1/notes/{noteId}/attachments/{attachmentId}/uploads`. Upload session persistence SHALL be keyed by `(note_id, attachment_id)`.

#### Scenario: Large attachment uses chunked path

- **WHEN** an attachment ciphertext size exceeds `NoteUploadSizeThreshold`
- **THEN** the client uses attachment chunked upload endpoints, not single PUT

#### Scenario: Upload session keyed by note and attachment

- **WHEN** a chunked attachment upload session is persisted
- **THEN** the session row is keyed by both note id and attachment id

### Requirement: Lazy migration to split storage

When reading or syncing a note whose decrypted payload is schema v1 (inline attachment data), `LocalNoteRepository` or sync layer SHALL migrate to split local files with v2 payload index, regenerate attachment UUIDs, and mark the note `pendingSync` for reupload.

#### Scenario: v1 note migrated on read

- **WHEN** a legacy note with inline attachments is read
- **THEN** attachment files are written under `attachments/`, body is rewritten with v2 index, and sync state becomes `pendingSync`

### Requirement: Delete note cascades attachments

`LocalNoteRepository.deleteNote` and remote delete SHALL remove the note body, all attachment files/rows, and attachment upload sessions for that note id.

#### Scenario: Delete removes attachment directory

- **WHEN** `deleteNote(noteID:)` succeeds
- **THEN** `notes/{noteID}/attachments/` is removed along with the note directory

## MODIFIED Requirements

### Requirement: NotesIndexStore schema

`NotesIndexStore` SHALL persist note index rows with columns: `note_id`, `title`, `created_at`, `updated_at`, `attachment_count`, `attachments_total_size`, `wrapped_fek`, `sync_state`, `body_etag`, and note-level `etag` when known from remote catalog.

#### Scenario: Row roundtrip preserves fields

- **WHEN** a note index row is upserted and fetched by `note_id`
- **THEN** all column values including `body_etag` and `etag` match the written row

### Requirement: LocalNoteRepository payload file storage

`LocalNoteRepository` SHALL persist SSNT wire body bytes at `Application Support/superSecureNotes/notes/{noteID}/body`. Encrypted attachment ciphertext SHALL be stored at `notes/{noteID}/attachments/{attachmentID}`. The legacy single `payload` file path SHALL NOT be used for new writes after migration.

#### Scenario: Write stores body file

- **WHEN** `writeNote` succeeds with a `StoredNote`
- **THEN** `notes/{noteID}/body` contains SSNT wire bytes assembled from metadata, wrapped FEK, and encrypted payload

#### Scenario: Legacy payload migrated on read

- **WHEN** `readNote` finds a legacy `payload` file without `body`
- **THEN** the repository migrates to split layout or throws a descriptive corrupt error if migration cannot complete

### Requirement: LocalNoteRepository delete and corrupt note handling

#### Scenario: Delete removes index row and note directory

- **WHEN** `deleteNote(noteID: id)` is called for an existing note
- **THEN** the index row and attachment rows are removed, `notes/{id}/` directory (including `body` and `attachments/`) is removed, and subsequent `readNote` throws `noteNotFound`

#### Scenario: Read incomplete note throws corruptNote

- **WHEN** `readNote(noteID:)` is called and an index row exists but the `body` file is missing
- **THEN** `NoteRepositoryError.corruptNote` is thrown

#### Scenario: Body without index row throws corruptNote

- **WHEN** `readNote(noteID:)` is called and a `body` file exists but no index row exists
- **THEN** `NoteRepositoryError.corruptNote` is thrown

### Requirement: NetworkNoteRepository StoredNote mapping

`NetworkNoteRepository` SHALL map `StoredNote` to remote split resources: SSNT body bytes via `/body` and per-attachment ciphertext via `/attachments/{id}`. On read, it SHALL fetch `/body`, parse SSNT sections into `StoredNote` fields, and fetch attachment bytes separately when requested by sync/hydration. It SHALL NOT use monolithic note PUT/GET. It SHALL NOT use `NotesIndexStore`.

#### Scenario: Network write uses split endpoints

- **WHEN** `writeNote` or upload helpers are called on `NetworkNoteRepository`
- **THEN** body and attachments are uploaded via their respective endpoints, not a single note blob endpoint

#### Scenario: Network read body parses SSNT

- **WHEN** body download succeeds
- **THEN** the returned metadata, wrapped FEK, and encrypted payload are parsed from SSNT body bytes with `syncState` appropriate to caller context

## REMOVED Requirements

### Requirement: NetworkNoteRepository monolithic wire blob upload

**Reason**: Backend replaced monolithic `PUT/GET /v1/notes/{noteId}` with split body and attachment endpoints.

**Migration**: Use `Network body and attachment API mapping` requirement and multi-part sync upload.
