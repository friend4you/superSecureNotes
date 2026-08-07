## Context

The backend API (`localhost:8000`) exposes:

| Resource | Endpoints |
|----------|-----------|
| Note index | `GET /v1/notes` → summaries with `attachmentCount`, `attachmentsTotalSize`, `etag` |
| Body | `GET/PUT /v1/notes/{noteId}/body` (≤10 MB, no chunked path) |
| Attachments | `GET /v1/notes/{noteId}/attachments` manifest; `GET/PUT/DELETE .../attachments/{attachmentId}`; chunked upload under `.../attachments/{attachmentId}/uploads` |
| Shared | `GET .../shared/{noteId}/body`, `.../attachments`, `.../attachments/{attachmentId}` |

Today the iOS client stores one encrypted payload file per note with inline attachment bytes. `NetworkNoteRepository` maps the whole `StoredNote` to a single SSNT wire blob via `PUT /v1/notes/{id}` (superseded). `LocalFirstNoteSyncService` pushes one blob per pending note.

## Goals / Non-Goals

**Goals:**

- Open note detail quickly from body alone (text + attachment filenames from decrypted index)
- Fetch attachment ciphertext in background with per-row progress (remote/cold path only)
- Mirror remote split in local storage for reliable divergence detection (body etag + per-attachment etag)
- Multi-part upload: body then attachments; note `pendingSync` until all succeed
- Lazy migration from v1 inline attachments to v2 split storage + new UUID attachment IDs
- Reuse upload-session persistence pattern from `add-chunked-note-upload`, keyed by `(note_id, attachment_id)`

**Non-Goals:**

- Note-level chunked upload (removed from API)
- Streaming decrypt/encrypt without loading attachment into memory (follow-up)
- Server-side migration of old monolithic blobs
- Changing SSNT `formatVersion` (stay v1); payload schema version lives inside ciphertext JSON
- Passing real MIME types to server (`application/octet-stream` only)

## Decisions

### 1. Remote body = SSNT-like wire blob

`PUT/GET /body` bytes are the same SSNT v1 envelope as today: plaintext metadata (title, timestamps, attachment counts), wrapped FEK, encrypted payload ciphertext. Title remains in plaintext header for list indexing consistency with `GET /v1/notes`.

**Rationale:** Minimal change to envelope; only inner `NotePayload` JSON changes.

### 2. NotePayload schema v2 (inside ciphertext)

```json
{
  "schemaVersion": 2,
  "body": "<utf8 text bytes>",
  "attachments": [
    { "id": "<uuid>", "filename": "receipt.pdf", "mime": "application/pdf", "size": 12345 }
  ]
}
```

v1 (no `schemaVersion` or `schemaVersion: 1`) keeps inline `data` on attachments. Decrypt detects version and migrates on next local write.

**Rationale:** Explicit version; filenames/mimes available immediately after body decrypt for UI.

### 3. Attachment blobs = `encrypt(fileBytes, noteFEK)`

Each local/remote attachment file stores ChaChaPoly ciphertext of raw file bytes only (no extra envelope). Same FEK as note body.

**Rationale:** Matches current crypto model; share grants (wrapped FEK) still cover all parts.

### 4. Local on-disk layout

```
notes/{noteId}/
  body              # SSNT wire bytes (same as remote /body)
  attachments/
    {attachmentId}  # encrypted file bytes
```

Index (`notes.db`):

- `notes` row: existing columns + `body_etag` (and note-level `etag` from list)
- `attachments` table: `(note_id, attachment_id)`, `etag`, `size_bytes`, `sync_state`
- `attachment_upload_sessions`: `(note_id, attachment_id)` → upload session fields (reuse chunked pattern)

`LocalNoteRepository.readNote` assembles `StoredNote` from index + body parse + decrypt payload + load attachment files for v2 (or inline from v1 payload during migration).

### 5. Sync upload ordering

On `flushPending()` for a pending note:

1. Ensure local body file + all attachment files exist
2. `PUT /body` with `If-Match` when etag known
3. For each attachment (added/changed): `PUT` or chunked upload; `DELETE` removed ids
4. Mark note `synced` only when all parts succeed; emit `NoteSyncOutcome`
5. On any failure or etag conflict: retry full note upload from local state (local wins)

Save button disabled while `syncState != synced`; fields remain editable only after synced (user can type but not commit).

### 6. Attachment hydration in `LocalFirstNoteSyncService`

When detail (or shared detail) opens and local attachment files are missing but manifest/index says they exist:

- Fetch manifest if needed (`GET .../attachments`)
- Download missing attachments in parallel (max 3 concurrent)
- Expose per-attachment progress (`bytesReceived / sizeBytes`) to ViewModels via stream/callback
- Downloads continue if user pops detail; ViewModel subscribes on re-entry
- Failed row: retry that attachment only
- Shared notes use `/v1/notes/shared/{id}/attachments/...` paths with same behavior

Warm local open: skip hydration; decrypt attachment files from disk.

### 7. Migration (lazy, client-driven)

On `readNote` or before upload:

- If decrypted payload is v1 (inline `data`): extract bytes to `attachments/{newUuid}`, build v2 index with regenerated UUIDs, rewrite body file, mark `pendingSync`
- No bulk migration on unlock

### 8. Supersede note-level chunked upload

Do not call `/v1/notes/{id}/uploads`. Repurpose `note_upload_sessions` → `attachment_upload_sessions` with composite key. Remove or no-op dead note-chunk paths in client when implementing this change.

## Risks / Trade-offs

- **[Save blocked while pending]** User cannot commit edits until sync completes → acceptable; offline users wait for connectivity or failed retry
- **[Body 10 MB cap]** Text + index must fit; attachment-heavy notes are fine since bytes are separate → monitor edge case of huge attachment metadata lists
- **[Local wins on conflict]** Remote edits could be overwritten → matches existing LWW posture; etag mismatch triggers full reupload from local
- **[Parallel downloads]** Cap at 3 balances speed vs memory/radio → tunable constant
- **[Migration UUID regen]** Old attachment id strings discarded → remote must accept new ids on first reupload after migration

## Migration Plan

1. Ship client with v2 read/write + lazy migration
2. Existing local notes migrate on first open/save
3. Pending notes reupload via split API on next `flushPending`
4. No server migration required; old monolithic server data assumed replaced or empty

## Open Questions

None — design decisions locked in explore session.
