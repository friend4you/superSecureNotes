## Context

Owned notes follow local-first sync: ViewModels call `LocalNoteRepository` only; `LocalFirstNoteSyncService` pulls `GET /v1/notes` on flush and first-device login; `listNotes()` reads the SQLCipher index.

Shared notes were implemented on the network layer (`NetworkNoteRepository`, segmented UI, shared detail) but `NotesFlow` is wired to `LocalNoteRepository`, which stubs sharing (`listSharedNotes()` → `[]`). The original `implement-note-sharing` design explicitly excluded local shared cache.

Split body/attachments APIs already exist for shared notes (`GET .../shared/{id}/body`, attachment manifest/chunks). `readSharedNote` still uses the legacy monolithic blob endpoint. Shared attachment hydration writes ciphertext via `writeAttachmentFile` but tests seed an owned-note shell; production has no stable `shared/{id}/` layout.

## Goals / Non-Goals

**Goals:**

- Shared list behaves like My Notes: local read, sync pull from `GET /v1/notes/shared` (unchanged response shape)
- Lazy body cache on detail open via `GET .../shared/{id}/body`; attachments hydrate into `shared/{id}/attachments/`
- Local-first shared delete (same release): instant local removal + outbox + remote `DELETE`
- Keep ViewModels on local `NoteRepository` + `NoteSyncing` (no composite repo in NotesFlow)
- Strict TDD; list + detail ship together

**Non-Goals:**

- Changes to `GET /v1/notes/shared` list JSON
- Sync status badges on Shared segment (read-only; no `pendingSync`)
- Local `shareNote` (ShareNote sheet keeps `networkNoteRepository`)
- Revoke-share UI for owners
- Editing shared notes
- Eager body download during catalog pull

## Decisions

### 1. Separate storage namespace (Option 1)

```
notes.db
  notes              ← owned catalog (unchanged)
  shared_notes       ← incoming share summaries
  shared_delete_outbox  ← pending remote DELETE (optional dedicated table or reuse pattern)

Application Support/superSecureNotes/
  notes/{noteId}/body + attachments/     ← owned
  shared/{noteId}/body + attachments/    ← shared cache
```

**Rationale:** Recipient-wrapped FEK differs from UDK-wrapped owned FEK; avoids `note_id` collisions between owned and shared namespaces; My Notes list cannot leak shared rows.

**Alternatives considered:**
- Single `notes` table with `kind` column — rejected; mixed FEK semantics and PK collision risk
- Network-only list with composite repo — rejected; breaks local-first parity

### 2. Sync orchestrator extension (not composite repository)

Extend `LocalFirstNoteSyncService`:

```
flushPending():
  flushUploads()           // owned only
  flushDeletes()           // owned only
  pullRemoteChanges()      // owned catalog
  pullRemoteSharedChanges() // NEW
  flushSharedDeletes()     // NEW
```

First-device login (after index open, same gate as owned):

```
pullRemoteNotesCatalog()
pullRemoteSharedCatalog()   // NEW — summaries only
```

ViewModels unchanged: `refresh()` → `flushPending()` → `listSharedNotes()` local read.

**Rationale:** Matches `add-local-first-sync` decision: orchestrator beside repo, not dual-write in ViewModels.

### 3. Shared catalog pull (summaries only)

`pullRemoteSharedChanges()` mirrors owned `pullRemoteChanges()`:

1. `GET /v1/notes/shared`
2. Compare etags with local `shared_notes` rows
3. Upsert changed/new summaries
4. Remove local rows (and purge `shared/{id}/`) absent from remote — share revoked

No body download during pull.

**Rationale:** Keeps list refresh lightweight; body fetched on detail open only.

### 4. Lazy body import on `readSharedNote`

`LocalNoteRepository.readSharedNote(noteID:)`:

```
if shared_notes row exists AND shared/{id}/body exists AND body_etag matches summary.etag:
  return SharedNote from local files
else:
  fetch GET /v1/notes/shared/{id}/body (via injectable remote/sync helper)
  persist recipient_wrapped_fek + SSNT body bytes to shared/{id}/body
  update body_etag on shared_notes row
  return SharedNote
```

Migrate off monolithic `GET /v1/notes/shared/{id}` `{ blob }` for client reads.

**Rationale:** Parity with owned split-body model; attachments already separate.

**Implementation seam:** Local repo may delegate network fetch to sync service or an internal `SharedNoteImporting` protocol to avoid circular deps — exact type is implementation detail; behavior is spec-defined.

### 5. Attachment hydration path

Update `LocalFirstNoteSyncService+AttachmentHydration` shared branch:

- Read/write attachment files under `shared/{noteId}/attachments/{attachmentId}`
- `DefaultSharedNoteDetailViewModel.refreshAttachmentPlaintext` reads from shared local layout (not `readNote` on owned path)

Require local body shell (from decision 4) before hydration lists manifest entries from inline payload metadata.

**Rationale:** Fixes accidental reuse of `notes/{id}/` for shared ciphertext.

### 6. Shared delete local-first

`deleteSharedNote(noteID:)`:

1. Remove `shared_notes` row and `shared/{id}/` directory immediately
2. Enqueue outbox entry for remote DELETE
3. `flushSharedDeletes()` sends `DELETE /v1/notes/shared/{id}`; failure retains outbox for retry without restoring UI row

Same release as body cache (Phase 2 in exploration — shipped together).

### 7. Detail VM simplification

`DefaultSharedNoteDetailViewModel.load()`:

- `ownerEmail` from `shared_notes` row (or `readSharedNote` companion lookup) — drop parallel `listSharedNotes()` fetch
- `readSharedNote` only for decrypt payload

### 8. Composition unchanged

`AppComposition` keeps `noteRepository: LocalNoteRepository` for NotesFlow. ShareNote keeps `networkNoteRepository`. No composite `NoteRepository` facade.

## Risks / Trade-offs

- **[Local repo calling network for body miss]** → Isolate behind sync/import protocol; test with injectable remote stub; only invoked on cache miss/stale etag
- **[Stale body after summary etag bump]** → Compare summary `etag` with stored `body_etag`; re-fetch on mismatch when opening detail
- **[Revoked share while detail open]** → Next list pull removes row; detail may show cached content until dismissed — acceptable v1
- **[Logout wipe]** → `shared_notes` and `shared/` live under same app support root as owned notes; existing logout reset must delete both trees
- **[Offline first open of uncached detail]** → `readSharedNote` fails without network; show error — same as owned cold start on new device before catalog pull

## Migration Plan

1. Schema migration adds `shared_notes` (+ outbox table if not reusing generic outbox)
2. Replace sharing stubs in `LocalNoteRepository`
3. Extend sync service pull/flush paths
4. Switch `NetworkNoteRepository.readSharedNote` / local import to split `/body`
5. Repoint shared attachment hydration to `shared/` tree
6. Update shared detail VM
7. Manual smoke: receive share → Shared segment shows row offline after sync → detail decrypts → attachments hydrate → delete removes locally and remotely

Rollback: revert package changes; Shared segment returns to empty stub behavior.

## Open Questions

- None — storage layout, lazy body, unchanged list API, and combined list+detail release confirmed in exploration.
