## ADDED Requirements

### Requirement: Attachment manifest chunk metadata

The attachment manifest (`GET /v1/notes/{noteId}/attachments` and shared equivalent) SHALL include `totalChunks` and `chunkSize` per entry. The client SHALL parse and store these fields on `RemoteAttachmentSummary` and use them for download loops.

#### Scenario: Manifest includes chunk fields

- **WHEN** the client decodes an attachment manifest entry from the server
- **THEN** `totalChunks` and `chunkSize` are available on the summary model

#### Scenario: Download loop uses server chunk count

- **WHEN** an attachment is downloaded using manifest metadata
- **THEN** the client requests chunk indices `0` through `totalChunks - 1` without recomputing chunk count from `sizeBytes` alone

### Requirement: Uniform chunked attachment upload

All attachment uploads SHALL use the init → chunk PUT(s) → complete flow under `/v1/notes/{noteId}/attachments/{attachmentId}/uploads`, regardless of ciphertext size. The client SHALL NOT call `PUT /v1/notes/{noteId}/attachments/{attachmentId}` for upload.

#### Scenario: Small attachment uses chunked upload

- **WHEN** an attachment ciphertext is 2048 bytes
- **THEN** the client calls init with `totalSize: 2048`, uploads one chunk at index `0`, then calls complete

#### Scenario: Multi-chunk attachment uses same pipeline

- **WHEN** an attachment ciphertext exceeds one chunk (`chunkSize` bytes, default 5_242_880)
- **THEN** the client uploads all required chunk indices before calling complete

#### Scenario: Upload init accepts any size from 1 byte

- **WHEN** init is called with `totalSize` of 1 or greater
- **THEN** the server returns `uploadId`, `chunkSize`, and `totalChunks` without rejecting small sizes

### Requirement: Attachment upload init request body

Upload init SHALL send JSON `{ "totalSize": <int>, "contentType": "application/octet-stream" }`.

#### Scenario: Init includes contentType

- **WHEN** attachment upload init is sent
- **THEN** the request body includes `totalSize` and `contentType` set to `application/octet-stream`

### Requirement: Owner attachment chunk download

Attachment download for owned notes SHALL use `GET /v1/notes/{noteId}/attachments/{attachmentId}/chunks/{chunkIndex}` for each index. The client SHALL concatenate chunk bytes in order to produce the full ciphertext blob.

#### Scenario: Single-chunk download

- **WHEN** manifest reports `totalChunks: 1` for an attachment
- **THEN** the client performs one chunk GET and returns the chunk bytes as the full attachment

#### Scenario: Multi-chunk download concatenates in order

- **WHEN** manifest reports `totalChunks: 3`
- **THEN** the client GETs indices `0`, `1`, and `2` and concatenates them in ascending index order

#### Scenario: Chunk response is opaque bytes

- **WHEN** a chunk GET succeeds
- **THEN** the response body is `application/octet-stream` opaque bytes for that chunk slice

### Requirement: Shared attachment chunk download

Shared attachment download SHALL use `GET /v1/notes/shared/{noteId}/attachments/{attachmentId}/chunks/{chunkIndex}` with the same concatenation semantics as owner download.

#### Scenario: Shared note downloads via shared chunk path

- **WHEN** a shared attachment is downloaded
- **THEN** the client uses `/v1/notes/shared/{noteId}/attachments/{attachmentId}/chunks/{index}` and does not call the owner blob GET path

### Requirement: Removed attachment blob endpoints not called

The client SHALL NOT call removed attachment blob endpoints after this change is implemented.

#### Scenario: No PUT attachment blob upload

- **WHEN** any attachment is uploaded to the network
- **THEN** no HTTP request is sent to `PUT .../attachments/{attachmentId}` without `/uploads` in the path

#### Scenario: No GET attachment blob download

- **WHEN** any attachment is downloaded from the network
- **THEN** no HTTP request is sent to `GET .../attachments/{attachmentId}` without `/chunks/` in the path

### Requirement: Attachment upload session reuse unchanged

Uniform chunked upload SHALL reuse existing attachment upload session persistence keyed by `(note_id, attachment_id)` including resume, wire-size mismatch invalidation, and per-chunk retry. Only the size gate for entering chunked mode is removed.

#### Scenario: Interrupted small attachment upload resumes

- **WHEN** a 2 KB attachment upload completes chunk `0` but complete fails, and the app restarts
- **THEN** resume skips chunk `0` and retries complete with the same `upload_id`
