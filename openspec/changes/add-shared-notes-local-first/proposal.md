## Why

The Shared segment in NotesFlow is wired to `LocalNoteRepository`, which stubs all sharing methods — so the list is always empty despite a working network implementation. The original note-sharing design also treated shared notes as network-only per session, which diverges from the local-first model already used for owned notes (`listNotes()` reads local index; sync pulls remote catalog on refresh and first login).

Recipients need the same experience as My Notes: instant list from local storage, background sync from `GET /v1/notes/shared`, and lazy body fetch on detail open using the split shared body endpoint (body separate from attachments).

## What Changes

- Add a local `shared_notes` SQLCipher table and a separate on-disk tree `shared/{noteId}/` for cached body and attachment ciphertext files (distinct from owned `notes/{noteId}/`)
- `LocalNoteRepository.listSharedNotes()` reads the local shared index instead of returning `[]`
- Extend `LocalFirstNoteSyncService` with shared catalog pull (`pullRemoteSharedChanges`) on `flushPending()` and first-device login (same gate as owned `pullRemoteNotesCatalog`)
- `readSharedNote(noteID:)` becomes local-first: return cached body from `shared/{noteId}/` when present and etag matches; otherwise fetch `GET /v1/notes/shared/{noteId}/body`, persist locally, then return
- Migrate shared read off the legacy monolithic `GET /v1/notes/shared/{noteId}` blob endpoint; attachments continue via existing shared manifest/chunk hydration into `shared/{noteId}/attachments/`
- Shared delete becomes local-first: remove from local index and files immediately, enqueue remote `DELETE /v1/notes/shared/{noteId}` for sync flush (same release as body cache)
- `DefaultSharedNoteDetailViewModel` reads `ownerEmail` from the local shared index row; drop redundant `listSharedNotes()` call on load
- `GET /v1/notes/shared` list response shape unchanged (`SharedNoteSummary` fields as today)
- ViewModels keep talking only to `NoteRepository` (local) + `NoteSyncing`; no composite repository in NotesFlow
- **BREAKING (spec):** Reverses `implement-note-sharing` non-goal that shared notes have no local cache/index

## Capabilities

### New Capabilities

- `shared-notes-local-first`: Local shared index and file layout, sync catalog pull, lazy body import on detail open, local-first shared delete outbox, and shared attachment hydration paths under `shared/`

### Modified Capabilities

- `note-repository`: Replace sharing stubs with local index read/write; `readSharedNote` local-first via split `/body`; shared delete outbox; `NotesIndexStore` shared table migration
- `notes-flow`: Shared list/detail behavior aligned with owned local-first flow; detail VM owner email from index

## Impact

- `Packages/NoteRepository/` — `NotesIndexStore` schema, `LocalNoteRepository`, `LocalFirstNoteSyncService`, `NetworkNoteRepository` (split shared body read), sync internal protocols
- `Packages/NotesFlow/` — `DefaultNoteListViewModel` (unchanged API; behavior fixed via repo/sync), `DefaultSharedNoteDetailViewModel`
- `Packages/AuthFlow/` — first-device login pulls shared catalog alongside owned notes
- `superSecureNotes/AppComposition.swift` — no composite repo; confirm NotesFlow local repo + sync wiring
- Supersedes local-cache non-goals in `openspec/changes/implement-note-sharing/` (implementation complete but wiring/cache incomplete)
- Depends on existing API: `GET /v1/notes/shared`, `GET /v1/notes/shared/{id}/body`, shared attachment manifest/chunks, `DELETE /v1/notes/shared/{id}`
