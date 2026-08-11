## Why

The backend is removing single-request attachment upload (`PUT .../attachments/{id}`) and full-blob download (`GET .../attachments/{id}`) in favor of **chunk-only** flows for all attachment sizes. The mobile client still branches on `NoteUploadSizeThreshold` (≤10 MB → PUT, >10 MB → chunked upload) and downloads attachments via one full GET. After the server upgrade those routes return 404, breaking sync and hydration for every attachment.

This is a **breaking, coordinated release** — the app must ship with the new chunk download path and unified chunk upload before or alongside the server deploy.

## What Changes

- **BREAKING**: Remove `PUT /v1/notes/{noteId}/attachments/{attachmentId}` upload path — all uploads use init → chunk(s) → complete
- **BREAKING**: Remove `GET .../attachments/{attachmentId}` full-blob download — download via `GET .../chunks/{index}` loop and client-side concatenation
- **BREAKING**: Remove `GET .../shared/.../attachments/{attachmentId}` full-blob download — same chunk loop under shared paths
- Remove size-based attachment upload branching (`NoteUploadSizeThreshold` no longer applies to attachments)
- Parse `totalChunks` and `chunkSize` from attachment manifest JSON; use server values for download loops
- Update attachment hydration to download chunks with incremental progress per chunk
- Include optional `contentType` in attachment upload init request body
- Unchanged: note body `PUT/GET /body` (≤10 MB), `DELETE` attachment, upload chunk PUT + complete, upload session persistence, etag algorithms, composite note etag

## Capabilities

### New Capabilities

- `uniform-chunked-attachments`: Chunk-only attachment upload for all sizes; chunk download and concatenation for owner and shared notes; manifest chunk metadata parsing

### Modified Capabilities

- `note-repository`: Attachment API client and `NetworkNoteRepository` mapping — replace PUT/GET blob paths with uniform chunked upload and chunk download
- `note-attachment-hydration`: Download path uses chunk loop; progress updates incrementally as chunks arrive (delta from `split-note-body-attachments`)

## Impact

- `Packages/NoteRepository/` — `NoteAPIClient`, `NoteResponseDTO`, `RemoteAttachmentSummary`, `NetworkNoteRepository`, `LocalFirstNoteSyncService+AttachmentHydration`
- `Packages/NoteRepository/Tests/` — replace PUT/GET blob tests; add chunk download tests; update hydration and upload fixtures
- Backend API at `http://localhost:8000/v1` — requires server migrations 006–008 and chunk-only routes
- Depends on `split-note-body-attachments` infrastructure (split storage, chunked upload sessions, hydration orchestration)
- Coordinate app release with server deploy — no client re-upload needed for existing server-side data
