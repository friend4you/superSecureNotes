## Context

`AppDependencies` always wires `LocalVaultRepository` and `LocalNoteRepository`. Auth uses `NetworkAuthRepository` against `https://api.example.com/v1`, or DEBUG `InMemoryAuthRepository` when `-UseStubBackend` is set. Register/login already write/read vault headers through `vaultRepository`, which today means local disk only. `NetworkVaultRepository` / `NetworkNoteRepository` exist but are unused in composition. Notes already mark creates/edits as `pendingSync`. The API at `http://localhost:8000/v1` supports auth, vault header blobs, note CRUD with etags, and soft delete. Note PUT returns `200` + `{ syncState, updatedAt, etag }` (client still expects `204`).

## Goals / Non-Goals

**Goals:**

- Local-first: create/update/delete succeed locally first; network sync is fire-and-forget
- First login / empty local vault: pull vault header + owned notes from API into local storage, then work locally
- Last-write-wins conflicts via note `updatedAt`; send `If-Match` when a local etag is known
- Sync indicators on note list and note detail (`pendingSync` / `synced`; pending delete not shown after local remove)
- Retry pending push/delete on online unlock, pull-to-refresh, and network regain
- Always use live API base URL `http://localhost:8000/v1`; remove stub backend
- Fix network note PUT success handling for `200`

**Non-Goals:**

- Continuous background sync daemon / push notifications
- Chunked uploads (>10 MB)
- Sharing endpoints / ShareNote crypto
- Full multi-device merge UI (no conflict picker)
- Changing logout wipe semantics (still full local reset)
- Production HTTPS host configuration (localhost only for this change)

## Decisions

### 1. Sync orchestrator, not a composite repository

Introduce `NoteSyncService` (name may be `LocalFirstSyncCoordinator`) in the app target or a small package seam that:

- Depends on `LocalNoteRepository` / `LocalVaultRepository` (source of truth)
- Depends on `NetworkNoteRepository` / `NetworkVaultRepository` (or thin API clients) for transport
- Is called after local mutations and on retry triggers

ViewModels keep talking only to `NoteRepository` (local). Sync is injected beside the repository, not replacing it.

**Rationale:** Preserves offline CRUD and existing ViewModel contracts; avoids dual-write inside every ViewModel.

**Alternatives considered:**

- Swap `noteRepository` to network — rejected; breaks offline and contradicts local-first
- Composite repository that syncs inside `writeNote` — rejected; couples latency/errors into CRUD; harder to fire-and-forget

### 2. Empty-local pull gate

Treat “first login / empty local” as: local vault header missing (`LocalVaultRepository.readHeader` → `headerNotFound`) after successful auth.

Flow:

```
auth register/login succeeds
  → if local vault missing:
       GET /vault/header (404 → create path already wrote local on register)
       open index with unlocked keys
       GET /notes → for each noteId GET blob → write local with syncState=.synced + etag
  → else:
       use local vault/notes (no full pull)
```

Register path: create vault locally → write local header → fire-and-forget `PUT /vault/header` → no pull.

Login on new device: auth → pull vault → unlock with password → pull notes.

**Rationale:** Matches decision A (pull only when local empty). Unlock with existing local setup does not re-pull the full catalog.

**Alternatives considered:** Pull every unlock — deferred; larger scope.

### 3. Pending delete state

Extend `NoteSyncState` with `pendingDelete`.

Delete UX path:

1. Read note (optional) / capture etag if needed
2. Remove from UI by deleting local index row + payload **or** mark `pendingDelete` then exclude from `listNotes`
3. Enqueue remote `DELETE /notes/{id}`
4. On remote success, ensure no local residue; on failure keep tombstone/`pendingDelete` until retry

Preferred: **immediate local hard delete of payload + index**, plus a durable **outbox** row (note_id, op=delete, optional etag) so the note disappears from UI instantly while remote delete can retry.

If outbox is heavier than desired for v1, `pendingDelete` rows that `listNotes` filters out are acceptable — same UX.

**Rationale:** User asked delete local immediately + enqueue remote delete.

### 4. Last-write-wins

On push of `pendingSync`:

- If local `etag` present → send `If-Match`
- On `409 conflict` → `GET` remote note, compare `updatedAt`; higher wins
  - Local newer → retry PUT without If-Match (or with new etag after GET) per API rules
  - Remote newer → overwrite local with remote, mark `.synced`
- If no etag (never synced) → PUT without If-Match

On empty-local pull only: all remote notes become local `.synced` (no merge).

**Rationale:** Simple, matches API etag design; no conflict UI.

### 5. Fire-and-forget + indicators

- After `writeNote` / delete, kick `syncService.flushPending()` without blocking navigation
- UI reads `NoteSummary.syncState` (list) and detail `syncState` for badge/label
- Pending = cloud.slash or “Pending”; synced = subtle check / “Synced” (final copy in localization)

### 6. Retry triggers

Call `flushPending()` when:

1. Unlock completes and `networkReachability.isOnline`
2. Note list `refresh()` / pull-to-refresh
3. Network path becomes satisfied (observe `NetworkReachability`)

Failures leave state pending; no modal spam.

### 7. Network note PUT `200`

`NoteAPIClient.writeNote` accepts `200`, decodes `{ syncState, updatedAt, etag }`, returns that metadata to sync so local row can store etag and flip to `.synced`.

### 8. Composition / stub removal

```swift
static let apiBaseURL = URL(string: "http://localhost:8000/v1")!
authRepository = NetworkAuthRepository(baseURL:)
vaultRepository = LocalVaultRepository()      // source of truth
noteRepository = LocalNoteRepository(...)
networkVault = NetworkVaultRepository(..., tokenProvider:)
networkNotes = NetworkNoteRepository(..., tokenProvider:)
syncService = LocalFirstSyncService(localVault:..., networkVault:..., localNotes:..., networkNotes:...)
```

Remove `StubBackendConfiguration`, `InMemoryAuthRepository`, scheme `-UseStubBackend`, and stub-only tests (or rewrite to network URLProtocol stubs).

**ATS:** Simulator localhost HTTP is acceptable for this change; document that physical devices need Mac LAN IP + ATS exception as follow-up.

### 9. Etag in index schema

Add nullable `etag TEXT` column to `NotesIndexStore`. Migration: recreate or `ALTER TABLE` on open (SQLCipher). Expose on `StoredNote` or parallel sync metadata — prefer optional `etag: String?` on `StoredNote` or a small `NoteSyncMetadata` kept in index only and returned via extended `NoteSummary`.

`NoteSummary` gains `syncState` for list UI.

## Risks / Trade-offs

- **[Fire-and-forget loses work if app killed mid-queue]** → Durable pending/outbox in SQLCipher index; flush on next unlock
- **[LWW can silently drop edits]** → Accepted for v1; no conflict UI
- **[localhost + cleartext]** → Dev-only; production host later
- **[Register vault push fails]** → Local vault still usable; header stays pushable on retry (track vault as pending via flag/file sidecar or always attempt PUT when local header exists and server 404)
- **[Delete outbox vs pendingDelete rows]** → Choose one in implementation; both satisfy UX
- **[Empty-local detection false negatives]** → If partial local notes exist without vault, treat as corrupt/setup failure; do not half-pull

## Migration Plan

1. Schema: add `etag`, allow `pendingDelete` in `sync_state` CHECK
2. Network client PUT `200` + etag plumbing
3. Sync service + auth/register/login hooks
4. UI indicators + refresh flush
5. Remove stub; point base URL at localhost
6. Manual: register → create note (pending→synced) → reinstall/login on “empty” device → notes appear

Rollback: revert composition to local-only without sync service; local data format remains valid if etag column ignored.

## Open Questions

None — unanswered UI/retry/LWW/logout items defaulted in Decisions 4–6 and Goals (logout wipe unchanged; indicators on list + detail).
