## Why

The backend enforces a 10 MB limit on `PUT /notes/{noteId}` and exposes a separate chunked upload API for larger note blobs. The client currently uploads every note as a single PUT and only syncs on unlock, pull-to-refresh, or network regain — not on save — so large notes fail to upload and the UI never reflects background sync completion.

## What Changes

- Route note uploads by wire blob size: `<= 10_000_000` bytes use existing `PUT /notes/{noteId}`; larger blobs use `POST .../uploads` → chunk PUTs → `POST .../complete`
- Persist in-progress chunked upload sessions locally (upload id, chunk progress, etag for complete) and resume after app restart; retry failed chunks only
- Invalidate a persisted session when the local note blob size changes (local edit during upload)
- Trigger fire-and-forget `flushPending()` after successful create/detail save (local write still succeeds immediately)
- Publish sync outcomes (per-note success/failure) so list and detail UIs update from Pending to Synced without manual refresh
- Out of scope: chunked download, per-chunk progress UI, streaming assembly from disk (memory optimization follow-up)

## Capabilities

### New Capabilities

- `chunked-note-upload`: Size-based upload routing, chunked upload API client, durable upload-session persistence, and resume/retry semantics

### Modified Capabilities

- `note-repository`: Network upload path selects PUT vs chunked flow; local index stores upload sessions; sync service emits per-note upload results
- `notes-flow`: Create and detail save kick background sync; list and detail subscribe to sync results and update indicators; list reflects new notes after create save

## Impact

- `Packages/NoteRepository/` — `NoteAPIClient`, `NetworkNoteRepository`, `LocalFirstNoteSyncService`, `NotesIndexStore` schema for upload sessions, sync result publisher
- `Packages/NoteRepositoryProtocol/` — optional sync result types / publisher protocol surface
- `Packages/NotesFlow/` — inject sync into create/detail view models; list/detail observe sync outcomes
- `superSecureNotes/AppComposition.swift` — wire sync result publisher into notes dependencies
- Depends on existing backend upload endpoints at `http://localhost:8000/v1` (documented under **uploads** tag)
