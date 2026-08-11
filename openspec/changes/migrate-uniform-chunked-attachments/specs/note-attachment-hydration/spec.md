## MODIFIED Requirements

### Requirement: Per-attachment download progress

The sync layer SHALL expose per-attachment download progress as bytes received over total size for subscribers (detail and shared detail view models). Progress SHALL update incrementally as each attachment chunk is received during chunk-based download.

#### Scenario: Progress updates during download

- **WHEN** an attachment download receives additional bytes from a completed chunk GET
- **THEN** subscribers receive an updated fraction for that attachment id reflecting cumulative bytes received

#### Scenario: Progress reaches total on completion

- **WHEN** all chunks are downloaded and written to local storage
- **THEN** subscribers receive completion state with `bytesReceived` equal to manifest `sizeBytes`

### Requirement: Shared note attachment hydration

Shared note detail SHALL use shared attachment chunk endpoints (`/v1/notes/shared/{noteId}/attachments/{attachmentId}/chunks/{index}`) with the same hydration, progress, parallelism, and retry behavior as owned notes.

#### Scenario: Shared detail shows per-attachment progress

- **WHEN** a shared note is opened without local attachment files
- **THEN** per-attachment download progress is shown using shared chunk endpoints, not full-blob GET
