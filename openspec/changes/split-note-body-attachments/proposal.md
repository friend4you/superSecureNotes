## Why

The backend now stores note bodies and attachments as separate opaque blobs (`GET/PUT /v1/notes/{id}/body` and `/attachments/{id}`) instead of a single monolithic `.note` wire blob. The mobile client still embeds attachment bytes inside one encrypted payload and downloads the whole note before detail can open. That blocks fast note open, prevents per-attachment progress, and no longer matches the API.

## What Changes

- **BREAKING**: Network sync uses split body + per-attachment endpoints instead of `PUT/GET /v1/notes/{id}` monolithic blobs
- Introduce `NotePayload` schema v2: encrypted body contains text plus attachment index (`id`, `filename`, `mime`, `size`) with no inline attachment bytes; same note FEK for all parts
- Store attachments locally as separate encrypted files under `notes/{noteId}/attachments/{attachmentId}`; body uses SSNT-like wire bytes for remote `/body` (title, wrapped FEK, encrypted payload)
- Upload pipeline: wait until all local parts exist, then PUT body, then PUT each attachment (chunked when >10 MB); note stays `pendingSync` until all parts succeed; disable Save (not editing) while not synced
- Background attachment hydration via `LocalFirstNoteSyncService` when opening a note without local attachment files (remote/cold path): parallel downloads capped at 3, per-attachment progress on detail/shared detail, continue after leaving screen, retry failed row only
- Lazy migration: rewrite legacy v1 inline-attachment notes to split local storage on read/save; regenerate attachment IDs as UUIDs; reupload to new API
- Server `contentType` for uploads is always `application/octet-stream` (no real mime leak)
- On upload conflict/failure, reupload from local (local wins)
- Supersedes note-level chunked upload from `add-chunked-note-upload`; repurpose upload-session persistence keyed by `(note_id, attachment_id)` for attachment chunking

## Capabilities

### New Capabilities

- `split-note-storage`: Split local and remote note representation (body wire blob + per-attachment ciphertext files), payload schema v2, lazy migration from v1 inline attachments
- `note-attachment-hydration`: Background attachment download orchestration, per-attachment progress UI, parallel cap, shared-note parity

### Modified Capabilities

- `secure-crypto`: `NotePayload` v2 attachment index model; decrypt path distinguishes v1 (inline) vs v2 (index-only)
- `note-repository`: Local split file layout, index attachment rows + etags, `NetworkNoteRepository` body/attachment API client, multi-part sync upload, attachment chunked upload sessions
- `notes-flow`: Remote-only hydration UX, per-attachment download progress, Save disabled while `syncState != synced`

## Impact

- `Packages/SecureCrypto/` — `NotePayload` v2, migration helpers
- `Packages/NoteRepository/` — `NoteAPIClient`, `LocalNoteRepository`, `NetworkNoteRepository`, `LocalFirstNoteSyncService`, `NotesIndexStore` schema (body etag, attachment rows, upload sessions)
- `Packages/NoteRepositoryProtocol/` — attachment sync state types if needed
- `Packages/NotesFlow/` — detail/shared detail attachment progress, save gating
- `superSecureNotes/AppComposition.swift` — wire hydration into sync dependencies
- Backend at `http://localhost:8000/v1` (notes + uploads tags)
- `add-chunked-note-upload` change is obsolete for note-level chunking; do not extend it
