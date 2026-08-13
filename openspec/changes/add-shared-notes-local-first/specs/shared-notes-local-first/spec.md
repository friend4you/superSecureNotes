## ADDED Requirements

### Requirement: Shared notes local-first orchestration

The sync orchestrator SHALL treat incoming shared notes with the same list pattern as owned notes: ViewModels read shared summaries from the local repository; the orchestrator pulls remote shared catalog changes asynchronously. Shared notes SHALL NOT require a composite `NoteRepository` in NotesFlow.

#### Scenario: Shared list read is local only

- **WHEN** `DefaultNoteListViewModel.reloadSharedSummaries()` runs
- **THEN** only `noteRepository.listSharedNotes()` is invoked against local storage

#### Scenario: Refresh triggers shared catalog pull

- **WHEN** `DefaultNoteListViewModel.refresh()` runs while online
- **THEN** `noteSync.flushPending()` includes a shared catalog pull before reloading shared summaries

### Requirement: Shared catalog pull on flush

`LocalFirstNoteSyncService` SHALL implement `pullRemoteSharedChanges()` that downloads `GET /v1/notes/shared`, upserts local `shared_notes` rows when remote `etag` differs or the row is new, and removes local rows (and purged `shared/{noteId}/` files) for note IDs absent from the remote list. The method SHALL NOT download note bodies during catalog pull.

#### Scenario: New remote share appears locally

- **WHEN** flush runs and remote shared list contains a note ID not present locally
- **THEN** a `shared_notes` row is inserted with summary fields from the API response

#### Scenario: Unchanged etag skips write

- **WHEN** flush runs and a local shared row exists with the same `etag` as remote
- **THEN** the local row is not rewritten

#### Scenario: Revoked share removed locally

- **WHEN** flush runs and a local shared note ID is missing from the remote list
- **THEN** the local shared index row and `shared/{noteId}/` directory are removed

#### Scenario: Catalog pull does not fetch bodies

- **WHEN** `pullRemoteSharedChanges()` imports a new shared summary
- **THEN** no `GET /v1/notes/shared/{noteId}/body` request is made

### Requirement: First-device login shared catalog pull

When first-device login opens the notes index after vault pull (same gate as `pullRemoteNotesCatalog()`), the sync orchestrator SHALL also pull the full shared catalog into local storage. When a local vault header already exists, the orchestrator SHALL NOT perform a full shared catalog import on unlock.

#### Scenario: New device login pulls shared summaries

- **WHEN** login succeeds, local vault header was missing, index is opened, and `pullRemoteNotesCatalog()` runs
- **THEN** shared summaries from `GET /v1/notes/shared` are stored locally

#### Scenario: Existing local vault skips full shared pull on unlock

- **WHEN** unlock succeeds and a local vault header already exists
- **THEN** the orchestrator does not replace the entire local shared catalog with a blind full re-import (incremental pull on flush only)

### Requirement: Lazy shared body import on detail read

Shared note bodies SHALL be fetched from `GET /v1/notes/shared/{noteId}/body` only when opening detail (via `readSharedNote`) and the local body cache is missing or stale relative to the summary `etag`. Imported bodies SHALL be stored under `shared/{noteId}/body` with recipient-wrapped FEK metadata persisted for subsequent local reads.

#### Scenario: Cached body served locally

- **WHEN** `readSharedNote(noteID:)` is called and local body cache exists with matching summary etag
- **THEN** no network body request is made and a `SharedNote` is returned from local files

#### Scenario: Missing cache triggers body fetch

- **WHEN** `readSharedNote(noteID:)` is called and no local body cache exists for a known shared summary
- **THEN** the client fetches `GET /v1/notes/shared/{noteId}/body`, persists locally, and returns `SharedNote`

#### Scenario: Stale etag re-fetches body

- **WHEN** summary `etag` changed since body was cached
- **THEN** the next `readSharedNote` re-fetches the body and replaces the local cache

### Requirement: Shared attachment hydration storage path

Shared attachment hydration SHALL read and write ciphertext files under `shared/{noteId}/attachments/{attachmentId}` using shared attachment endpoints. It SHALL NOT write shared attachment files under `notes/{noteId}/attachments/`.

#### Scenario: Hydration uses shared directory

- **WHEN** `hydrateSharedAttachments(noteID:)` downloads an attachment
- **THEN** ciphertext is stored under the `shared/{noteId}/attachments/` tree

#### Scenario: Owned attachment path not used for shared

- **WHEN** shared attachment hydration completes
- **THEN** no new files are created under `notes/{noteId}/attachments/` for that shared note ID

### Requirement: Local-first shared delete flush

When the user deletes a shared note from the list, the app SHALL remove the shared index row and `shared/{noteId}/` files immediately and enqueue remote `DELETE /v1/notes/shared/{noteId}`. The orchestrator SHALL flush enqueued shared deletes during `flushPending()`; failures SHALL leave the delete pending for retry without restoring the row to the visible list.

#### Scenario: Delete removes shared row before remote ack

- **WHEN** the user confirms shared note delete
- **THEN** the note no longer appears in `listSharedNotes` even if remote DELETE has not completed

#### Scenario: Failed shared delete retries on flush

- **WHEN** remote shared DELETE fails during flush
- **THEN** a subsequent flush retries the delete without restoring the note to the Shared segment list

### Requirement: Logout wipes shared local cache

Logout reset SHALL delete `shared_notes` index data and the `shared/` file tree along with owned notes data.

#### Scenario: Logout clears shared cache

- **WHEN** logout reset completes
- **THEN** no `shared_notes` rows remain and the `shared/` directory is removed
