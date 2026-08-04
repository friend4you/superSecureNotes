## Context

`LocalFirstNoteSyncService` pushes `pendingSync` notes via `NetworkNoteRepository.uploadNote`, which assembles a wire-format `.note` blob and sends it in one `PUT`. The API rejects bodies over 10 MB and provides:

| Step | Endpoint |
|------|----------|
| Init | `POST /v1/notes/{noteId}/uploads` — `{ totalSize, contentType? }` → `{ uploadId, chunkSize, totalChunks }` |
| Chunk | `PUT /v1/notes/{noteId}/uploads/{uploadId}/chunks/{chunkIndex}` — raw bytes → `204` |
| Complete | `POST /v1/notes/{noteId}/uploads/{uploadId}/complete` — `{ ifMatch? }` → `{ syncState, updatedAt, etag }` |

Create/detail save writes locally with `pendingSync` but does not start sync. List/detail show sync indicators from last load only; nothing observes background upload completion.

## Goals / Non-Goals

**Goals:**

- Upload notes of any size supported by the backend chunked API
- Use single PUT when wire blob `<= 10_000_000` bytes; chunked flow when larger
- Persist upload session state in SQLCipher index; resume missing chunks after restart
- Retry individual failed chunk PUTs; invalidate session if local blob size changes
- Fire-and-forget sync immediately after create/detail save
- Update list/detail sync indicators when a note upload succeeds or remains pending after failure

**Non-Goals:**

- Chunked or streaming download
- Per-chunk progress bar (Pending until complete is sufficient for v1)
- Streaming wire blob assembly from disk without loading payload into memory
- Changing SSNT wire format or encryption layout

## Decisions

### 1. Size check on wire blob after `assembleNoteFile`

Compute `data.count` on the assembled opaque `.note` bytes in `NetworkNoteRepository.uploadNote` (or delegated upload helper).

- `count <= 10_000_000` → existing PUT path with optional `If-Match`
- `count > 10_000_000` → chunked path

**Rationale:** Matches API contract ("≤ 10 MB" on PUT). Header + FEK overhead is negligible vs attachment-heavy payloads.

### 2. Chunked upload orchestration in `NoteAPIClient` + `NetworkNoteRepository`

Add `initUpload`, `uploadChunk`, `completeUpload` to `NoteAPIClient`. `NetworkNoteRepository.uploadNote` branches on size and runs:

```
init(totalSize: wireBlob.count)
for index in 0..<totalChunks where index not in completedSet:
    PUT chunk[index] with wireBlob subrange
complete(ifMatch: etag)
```

Chunk body bytes are opaque slices of the wire blob at `[index * chunkSize ..< min(...)]` using server-returned `chunkSize`.

**Rationale:** Keeps transport logic in the network layer; sync orchestrator unchanged except for result publishing (Decision 5).

### 3. Upload session persistence in `NotesIndexStore`

New table `note_upload_sessions` (or equivalent) keyed by `note_id`:

| Column | Purpose |
|--------|---------|
| `note_id` | FK to note |
| `upload_id` | Server session UUID |
| `wire_size` | Total bytes — invalidate if re-assembled blob size differs |
| `chunk_size` | From init response |
| `total_chunks` | From init response |
| `completed_chunk_indices` | Serialized set (JSON array or comma-separated) |
| `if_match` | Optional etag for complete |

Upsert on init; update after each successful chunk; delete on complete success or invalidation.

**Rationale:** Durable resume across app kill; colocated with sync metadata in SQLCipher.

**Alternatives considered:**

- Sidecar file per note — rejected; splits sync state across stores
- UserDefaults — rejected; existing project pattern avoids it for sync data

### 4. Session invalidation on local edit

Before resuming, compare persisted `wire_size` to freshly assembled blob count. If different, delete session row and call `init` again.

**Rationale:** Prevents uploading stale bytes after local save while a prior upload was in progress.

On chunk/complete `404`/`410`, treat server session as expired: clear local session and restart from init.

### 5. Sync result publisher

Extend `LocalFirstNoteSyncService` (or adjacent type) to emit `NoteSyncOutcome` events:

```swift
enum NoteSyncOutcome: Sendable {
    case uploaded(noteID: UUID, syncState: NoteSyncState, updatedAt: UInt64, etag: String?)
    case uploadFailed(noteID: UUID) // remains pendingSync
}
```

Expose `AsyncStream<NoteSyncOutcome>` or `@Observable` hub injected into `NotesFlowDependencies`.

After each note push attempt in `flushPending`, emit outcome. ViewModels subscribe and patch UI.

**Rationale:** Decouples sync from SwiftUI; list/detail update without polling DB.

### 6. Fire-and-forget sync on save

Inject `NoteSyncing` (or narrow `NoteSyncScheduling` with `scheduleFlush()`) into `DefaultCreateNoteViewModel` and `DefaultNoteDetailViewModel`.

After successful `writeNote`:

```swift
syncState = .pendingSync  // detail only; create pops
noteSync.scheduleFlush()   // non-blocking Task { await flushPending() }
```

Save does not await network. Navigation is not blocked.

**Rationale:** Matches user expectation: immediate local success, background upload, UI reacts on result.

### 7. List refresh after create save

`DefaultNoteListViewModel` subscribes to sync outcomes and also reloads summaries when:

- Any upload outcome arrives (patch or `listNotes()`)
- Create save completes — list VM notified via outcome stream after flush starts, or explicit `noteCreated` callback from navigation pop

Simplest v1: on any `NoteSyncOutcome`, call lightweight `reloadSummaries()` from local repo. Additionally, after create pop, list `.onAppear` or navigation callback triggers `reloadSummaries()` so the new row appears with Pending before upload finishes.

**Rationale:** Fixes gap where new note does not appear until pull-to-refresh.

## Risks / Trade-offs

- **[Large blob memory]** → v1 loads full wire blob for chunk slicing; document streaming follow-up
- **[Stale uploadId on server]** → Clear local session and re-init on 404/410
- **[Concurrent flush + save]** → `LocalFirstNoteSyncService` actor serializes flush; session row per note_id prevents cross-note confusion
- **[UI misses event if detail closed]** → Acceptable; next `load()` or list refresh shows correct state from DB
- **[LWW during long chunked upload]** → Same as today; complete sends `ifMatch` when etag known; conflict handling unchanged

## Migration Plan

1. Add `note_upload_sessions` table migration on index open
2. Implement chunked API client + branch in `uploadNote`
3. Persist/resume sessions in flush path
4. Add sync outcome stream + wire into NotesFlow
5. Add scheduleFlush on create/detail save
6. Manual: create small note → Pending → Synced without pull-to-refresh; create >10 MB note (or test stub) → chunked path completes

Rollback: ignore upload_sessions table; fall back to PUT-only (large notes fail at server — pre-change behavior).

## Open Questions

None — exploration decisions captured above.
