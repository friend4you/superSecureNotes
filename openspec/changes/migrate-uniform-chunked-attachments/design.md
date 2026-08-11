## Context

The backend API (`/v1`) is moving to **uniform chunked attachments**. After server migrations 006–008:

| Operation | Removed | Required |
|-----------|---------|----------|
| Upload | `PUT .../attachments/{id}` | `POST init` → `PUT chunks/{i}` → `POST complete` |
| Download (owner) | `GET .../attachments/{id}` | `GET .../chunks/{index}` per chunk |
| Download (shared) | `GET .../shared/.../attachments/{id}` | `GET .../shared/.../chunks/{index}` |

The iOS client (`split-note-body-attachments`) already implements chunked **upload** for attachments > `NoteUploadSizeThreshold` (10_485_760 bytes) with session persistence keyed by `(note_id, attachment_id)`. Small attachments still use single PUT. Hydration downloads full blobs via single GET.

Note body endpoints (`PUT/GET /body`, ≤10 MB) are unchanged.

Reference: `super-secure-notes-api/docs/mobile-migration-chunked-attachments.md`

## Goals / Non-Goals

**Goals:**

- Single upload pipeline for all attachment sizes (including 2 KB files)
- Single download pipeline: manifest → chunk loop → concatenate → write local file
- Parse `totalChunks` and `chunkSize` from manifest; prefer server values over client recomputation
- Owner and shared download parity
- Incremental hydration progress as chunks arrive
- Reuse existing attachment upload session persistence and retry logic
- Coordinate release with backend deploy

**Non-Goals:**

- Changing note body upload/download (still single PUT/GET)
- Streaming decrypt without full in-memory concatenation (follow-up)
- Client-side re-upload of existing server attachments after upgrade (server migrates data)
- Changing etag algorithms or composite note etag formula
- Removing `NoteUploadSizeThreshold` constant if still referenced elsewhere (only stop using it for attachments)

## Decisions

### 1. Upload — always chunked, remove PUT branch

`NetworkNoteRepository.uploadAttachment` SHALL always call the existing `uploadAttachmentChunked` path. Remove the `ciphertext.count <= NoteUploadSizeThreshold` branch and stop calling `apiClient.writeAttachment`.

**Rationale:** Matches backend; reuses session persistence, retry, and resume already built for large files. Trade-off: 3 HTTP requests for a 2 KB file (accepted by backend design).

**Alternative considered:** Keep PUT as fallback behind feature flag — rejected; backend removes the route entirely.

### 2. Download — chunk loop in `NetworkNoteRepository`

Add `readAttachmentChunk` / `readSharedAttachmentChunk` on `NoteAPIClient`. Add `readAttachment` / `readSharedAttachment` on `NetworkNoteRepository` that:

1. Accept `RemoteAttachmentSummary` (with `totalChunks`, `chunkSize`) or fetch manifest entry
2. Loop `0..<totalChunks`, GET each chunk
3. Concatenate into `Data`
4. Return full ciphertext

Hydration continues calling `readAttachment` / `readSharedAttachment` at repository level — no chunk awareness in `LocalFirstNoteSyncService+AttachmentHydration` beyond progress callbacks.

**Rationale:** Keeps hydration simple; chunk logic centralized in network layer.

### 3. Manifest model extension

Extend `AttachmentSummaryResponseDTO` and `RemoteAttachmentSummary` with `totalChunks: Int` and `chunkSize: Int` (required fields from server).

**Rationale:** Server is source of truth for chunk geometry; avoids client recomputation drift.

### 4. Hydration progress — per-chunk increments

`downloadOneAttachment` passes `summary` with chunk metadata. After each chunk GET, emit progress with `bytesReceived` += chunk length. Final emit on write to disk.

**Rationale:** Better UX for large files; aligns with spec scenario for incremental progress.

### 5. Remove dead API client methods

Delete `writeAttachment`, and replace blob `readAttachment` / `readSharedAttachment` on `NoteAPIClient` with chunk methods. Repository layer owns concatenation.

**Rationale:** Prevents accidental use of removed routes.

### 6. Upload init includes contentType

Send `{ "totalSize": N, "contentType": "application/octet-stream" }` on init (always octet-stream per existing policy).

**Rationale:** Backend accepts it; future-proofs without exposing real MIME.

### 7. Optional etag verification after download

After concatenation, optionally verify `SHA-256(concatenated) == manifest.etag` in debug/test builds only — not required for v1 unless tests need it.

**Rationale:** Backend preserves etag algorithm; verification catches corruption but adds crypto dependency in network layer.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| App ships before server → 404 on old PUT/GET paths | Coordinate release; document dependency on migrations 006–008 |
| Server ships before app → downloads/uploads fail | Same — treat as coordinated release |
| 3 HTTP round-trips for tiny uploads | Accepted backend trade-off; no client optimization |
| Full attachment still loaded in memory on download | Same as today; streaming is follow-up |
| Tests extensively mock PUT/GET blob paths | Sweep tests in same change; update fixtures |

## Migration Plan

1. Implement chunk download + remove upload branch behind tests
2. Run full `NoteRepository` test suite
3. Manual e2e: 2 KB attachment upload/download, >5 MB multi-chunk, shared note download
4. Ship app build with server deploy in same window
5. No local data migration required — server preserves etags and splits inline blobs

## Open Questions

- None blocking — backend migration doc is complete. Etag verification on download: defer unless tests require it.
