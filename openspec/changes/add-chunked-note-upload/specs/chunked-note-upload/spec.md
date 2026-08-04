## ADDED Requirements

### Requirement: Upload size threshold constant

The `NoteRepository` module SHALL define a constant `NoteUploadSizeThreshold` equal to `10_000_000` bytes representing the maximum wire blob size for single-request note upload per the backend API.

#### Scenario: Threshold matches API limit

- **WHEN** client code compares an assembled wire blob size to `NoteUploadSizeThreshold`
- **THEN** the threshold value is `10_000_000`

### Requirement: Single-request upload for small wire blobs

When an assembled opaque `.note` wire blob size is less than or equal to `NoteUploadSizeThreshold`, `NetworkNoteRepository` SHALL upload via `PUT /v1/notes/{noteId}` with `Content-Type: application/octet-stream`, optional `If-Match`, and the full wire blob as the request body.

#### Scenario: Ten megabyte blob uses PUT

- **WHEN** `uploadNote` assembles a wire blob of exactly `10_000_000` bytes
- **THEN** the client sends a single PUT to `/v1/notes/{noteId}` and does not call chunked upload endpoints

#### Scenario: Sub-threshold blob uses PUT

- **WHEN** `uploadNote` assembles a wire blob smaller than `NoteUploadSizeThreshold`
- **THEN** the client sends a single PUT to `/v1/notes/{noteId}`

### Requirement: Chunked upload for large wire blobs

When an assembled opaque `.note` wire blob size is greater than `NoteUploadSizeThreshold`, `NetworkNoteRepository` SHALL upload using the backend chunked upload flow: `POST /v1/notes/{noteId}/uploads`, then `PUT` each required chunk to `/v1/notes/{noteId}/uploads/{uploadId}/chunks/{chunkIndex}` with opaque byte slices of the wire blob, then `POST /v1/notes/{noteId}/uploads/{uploadId}/complete` with optional `ifMatch` in the JSON body.

#### Scenario: Over-threshold blob uses chunked flow

- **WHEN** `uploadNote` assembles a wire blob of `10_000_001` bytes
- **THEN** the client initiates a chunked upload session and does not send the full blob in a single PUT

#### Scenario: Init sends totalSize

- **WHEN** chunked upload begins for a wire blob
- **THEN** the init request body includes `totalSize` equal to the wire blob byte count

#### Scenario: Complete returns upload metadata

- **WHEN** all required chunks are uploaded and complete succeeds with HTTP 200
- **THEN** the client parses `syncState`, `updatedAt`, and `etag` from the complete response the same as a successful PUT upload

### Requirement: Per-chunk upload retry

During chunked upload, the client SHALL retry only the chunk PUT that failed before proceeding to the next missing chunk or complete. Successfully uploaded chunk indices SHALL NOT be re-sent unless the upload session is invalidated and restarted.

#### Scenario: Failed chunk is retried

- **WHEN** chunk index `2` fails with a retryable network error and a subsequent attempt succeeds
- **THEN** chunk index `2` is marked complete locally and upload continues without re-uploading indices `0` and `1`

### Requirement: Durable chunked upload session persistence

`NotesIndexStore` SHALL persist an in-progress chunked upload session per note including at minimum: `note_id`, `upload_id`, `wire_size`, `chunk_size`, `total_chunks`, completed chunk indices, and optional `if_match` for complete. The session SHALL survive app restart until upload completes successfully or the session is invalidated.

#### Scenario: Session survives restart

- **WHEN** a chunked upload has completed some but not all chunks and the app process terminates
- **THEN** reopening the index and flushing pending uploads resumes the same `upload_id` and skips already completed chunk indices

#### Scenario: Session cleared on complete

- **WHEN** chunked upload complete succeeds and the note is marked synced locally
- **THEN** the persisted upload session row for that note is deleted

### Requirement: Upload session invalidation on local blob change

Before resuming a persisted chunked upload session, the client SHALL compare the persisted `wire_size` to the freshly assembled wire blob size for the current local note. If they differ, the client SHALL delete the persisted session and start a new init upload for the current blob.

#### Scenario: Local edit invalidates session

- **WHEN** a note is saved locally while a chunked upload session exists and the new assembled wire blob size differs from the persisted `wire_size`
- **THEN** the old upload session is discarded and a new init upload is created for the updated blob

#### Scenario: Expired server session restarts

- **WHEN** chunk upload or complete returns a not-found style error indicating the server upload session no longer exists
- **THEN** the client clears the local session and restarts chunked upload from init
