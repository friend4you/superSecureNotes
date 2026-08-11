## ADDED Requirements

### Requirement: NoteAPIClient attachment chunk download

`NoteAPIClient` SHALL expose methods to download a single attachment chunk for owner and shared paths. Responses SHALL be raw `Data` bytes.

#### Scenario: Owner chunk GET path

- **WHEN** `readAttachmentChunk` is called with `chunkIndex: 0`
- **THEN** the client sends `GET /v1/notes/{noteId}/attachments/{attachmentId}/chunks/0`

#### Scenario: Shared chunk GET path

- **WHEN** `readSharedAttachmentChunk` is called with `chunkIndex: 1`
- **THEN** the client sends `GET /v1/notes/shared/{noteId}/attachments/{attachmentId}/chunks/1`

### Requirement: NetworkNoteRepository concatenates attachment chunks

`NetworkNoteRepository.readAttachment` and `readSharedAttachment` SHALL download all chunks using manifest `totalChunks` and `chunkSize`, concatenate, and return the full ciphertext. They SHALL NOT call full-blob GET endpoints.

#### Scenario: Repository returns concatenated ciphertext

- **WHEN** `readAttachment` is called for an attachment with `totalChunks: 2`
- **THEN** two chunk GETs are performed and the returned `Data` length equals `sizeBytes` from the manifest

## MODIFIED Requirements

### Requirement: Network body and attachment API mapping

`NetworkNoteRepository` SHALL upload and download notes using `GET/PUT /v1/notes/{noteId}/body` for SSNT body bytes. Attachment upload SHALL use init → chunk PUT(s) → complete under `/v1/notes/{noteId}/attachments/{attachmentId}/uploads` for all sizes. Attachment download SHALL use chunk GETs under `/v1/notes/{noteId}/attachments/{attachmentId}/chunks/{index}` concatenated client-side. Attachment delete SHALL use `DELETE /v1/notes/{noteId}/attachments/{attachmentId}`. It SHALL list attachment manifests via `GET /v1/notes/{noteId}/attachments`. Upload `contentType` SHALL be `application/octet-stream`. It SHALL NOT use monolithic `PUT/GET /v1/notes/{noteId}` for note content. It SHALL NOT use `PUT` or full-blob `GET` on `/attachments/{attachmentId}`.

#### Scenario: Upload body uses body endpoint

- **WHEN** a note body is uploaded to the network repository
- **THEN** the client sends `PUT /v1/notes/{noteId}/body` with SSNT wire bytes

#### Scenario: Upload attachment uses chunked flow

- **WHEN** an attachment is uploaded regardless of size
- **THEN** the client uses init → chunks → complete and does not send `PUT .../attachments/{attachmentId}`

#### Scenario: Download attachment by chunks

- **WHEN** an attachment is downloaded
- **THEN** the client calls chunk GET endpoints for each index and returns concatenated ciphertext bytes

### Requirement: Attachment chunked upload sessions

All attachment uploads SHALL use `POST/PUT/POST complete` under `/v1/notes/{noteId}/attachments/{attachmentId}/uploads`. Upload session persistence SHALL be keyed by `(note_id, attachment_id)`. Size-based branching on `NoteUploadSizeThreshold` SHALL NOT apply to attachments.

#### Scenario: Small attachment uses chunked path

- **WHEN** an attachment ciphertext size is 2048 bytes
- **THEN** the client uses attachment chunked upload endpoints, not single PUT

#### Scenario: Upload session keyed by note and attachment

- **WHEN** a chunked attachment upload session is persisted
- **THEN** the session row is keyed by both note id and attachment id

## REMOVED Requirements

### Requirement: Single PUT attachment upload for sub-threshold sizes

**Reason**: Backend removed `PUT /v1/notes/{noteId}/attachments/{attachmentId}`; all uploads are chunk-only.

**Migration**: Use uniform chunked upload (init → chunks → complete) for every attachment size.

### Requirement: Full-blob GET attachment download

**Reason**: Backend removed `GET /v1/notes/{noteId}/attachments/{attachmentId}` and shared equivalent; downloads are chunk-only.

**Migration**: Use chunk GET loop and client-side concatenation per `uniform-chunked-attachments` capability.
