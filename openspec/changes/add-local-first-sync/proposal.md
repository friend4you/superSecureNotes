## Why

The app stores vault headers and notes only on device (`LocalVaultRepository`, `LocalNoteRepository`) while `Network*` clients and a real API at `http://localhost:8000/v1` already exist. Without local-first sync, multi-device restore and server-backed backup are impossible, and DEBUG still relies on an in-memory stub instead of the live backend.

## What Changes

- Add a local-first sync layer: write/delete locally first, then fire-and-forget push to the API; on first login (empty local vault), pull vault header and owned notes from the backend into local storage
- Conflict policy: last-write-wins using note `updatedAt` (etag used for conditional upload when known)
- Extend sync states with `pendingDelete`; delete removes local data immediately and enqueues remote delete
- Show synced vs pending indicators on the note list and note detail screens
- Retry pending uploads/deletes when unlocking online, on pull-to-refresh, and when network becomes reachable again
- Point `AppDependencies.apiBaseURL` at `http://localhost:8000/v1`
- **BREAKING (DEBUG):** remove `-UseStubBackend` / `InMemoryAuthRepository` / stub wiring; always use `NetworkAuthRepository`
- Fix `NetworkNoteRepository` / `NoteAPIClient` to accept note PUT `200` + upload response (API no longer returns `204`)
- Persist etag (and sync state) in the local notes index for LWW / `If-Match`
- Out of scope: chunked uploads (>10 MB), note sharing endpoints, continuous background sync daemon, multi-account on one device

## Capabilities

### New Capabilities

- `local-first-sync`: Orchestrates vault + note pull on empty local setup, push of pending creates/updates/deletes, retry triggers, localhost API composition, and stub removal

### Modified Capabilities

- `note-repository`: `pendingDelete` sync state, `NoteSummary.syncState`, etag column, network PUT `200` handling, local delete enqueue semantics for sync
- `notes-flow`: Sync status indicators on list and detail; refresh triggers pending sync flush

## Impact

- `superSecureNotes/AppDependencies.swift` — base URL, remove stub auth gate, wire sync orchestrator + token provider into network clients
- `Packages/NoteRepository/` — sync state, index schema, network client PUT response, optional sync helpers
- `Packages/VaultRepository/` — network client used by sync for header upload/download (local remains source of truth)
- `Packages/NotesFlow/` — list/detail sync indicators; refresh kicks sync
- `Packages/AuthFlow/` — first-login / empty-local pull hook after register/login unlock path
- `superSecureNotes/Stub/` and related DEBUG tests — stub auth removed
- Depends on running `super-secure-notes-api` at localhost:8000 (register already returns 201 / duplicate 409)
