## 1. Shared notes index schema

- [ ] 1.1 Write failing tests: `shared_notes` row upsert/fetch roundtrip preserves all fields including optional `body_etag`; owned `notes` and `shared_notes` rows for the same UUID can coexist (`NotesIndexStoreSharedNotesTests`)
- [ ] 1.2 Add `shared_notes` table migration and query helpers on `NotesIndexStore`; make tests pass

## 2. Local shared file layout helpers

- [ ] 2.1 Write failing tests: shared body write/read under `shared/{noteId}/body`; shared attachment write/read under `shared/{noteId}/attachments/{attachmentId}`; no files created under `notes/{noteId}/` (`LocalNoteRepositorySharedStorageTests`)
- [ ] 2.2 Implement shared directory paths and atomic body/attachment file helpers on `LocalNoteRepository`; make tests pass

## 3. LocalNoteRepository listSharedNotes

- [ ] 3.1 Write failing tests: `listSharedNotes()` returns summaries from `shared_notes` index; returns `[]` when empty; throws `databaseNotOpen` when index closed; does not call network (`LocalNoteRepositorySharedListTests`)
- [ ] 3.2 Replace sharing list stub with local index read; make tests pass

## 4. Network shared body import

- [ ] 4.1 Write failing tests: `NetworkNoteRepository.readSharedBody(noteID:)` parses `GET /v1/notes/shared/{id}/body` into `SharedNote`; does not call monolithic blob endpoint (`NetworkNoteRepositorySharedBodyTests`)
- [ ] 4.2 Implement `readSharedBody` on `NetworkNoteRepository` / wire `NoteAPIClient.readSharedBody`; make tests pass

## 5. LocalNoteRepository readSharedNote local-first

- [ ] 5.1 Write failing tests: cached body + matching etag returns local `SharedNote` without network; missing cache imports via split body and persists; stale etag re-imports (`LocalNoteRepositoryReadSharedNoteTests`)
- [ ] 5.2 Implement local-first `readSharedNote` with injectable remote import seam; make tests pass

## 6. Shared catalog sync pull

- [ ] 6.1 Write failing tests: `pullRemoteSharedChanges()` upserts new/changed summaries by etag; removes revoked shares and purges `shared/{id}/`; does not fetch bodies (`LocalFirstNoteSyncServiceSharedPullTests`)
- [ ] 6.2 Extend `NoteSyncRemoteStoring` / `NoteSyncLocalStoring` and implement `pullRemoteSharedChanges()`; call from `flushPending()`; make tests pass

## 7. First-device login shared catalog pull

- [ ] 7.1 Write failing tests: new-device login path invokes shared catalog pull alongside `pullRemoteNotesCatalog()`; existing local vault unlock skips full shared re-import (`DefaultLoginViewModelSharedPullTests`, `LocalFirstNoteSyncServiceSharedPullTests`)
- [ ] 7.2 Add `pullRemoteSharedCatalog()` and wire into login first-device flow; make tests pass

## 8. Shared attachment hydration paths

- [ ] 8.1 Write failing tests: `hydrateSharedAttachments` writes to `shared/{id}/attachments/`; `DefaultSharedNoteDetailViewModel.refreshAttachmentPlaintext` reads shared layout; owned `notes/{id}/attachments/` untouched (`SharedAttachmentHydrationStorageTests`, `DefaultSharedNoteDetailViewModelAttachmentTests`)
- [ ] 8.2 Repoint shared hydration and detail attachment refresh to shared storage helpers; make tests pass

## 9. Local-first shared delete

- [ ] 9.1 Write failing tests: `deleteSharedNote` removes index row and `shared/{id}/` immediately; enqueues outbox; `flushSharedDeletes()` sends `DELETE /v1/notes/shared/{id}` with retry on failure (`LocalNoteRepositorySharedDeleteTests`, `LocalFirstNoteSyncServiceSharedDeleteTests`)
- [ ] 9.2 Implement shared delete outbox + flush; make tests pass

## 10. NotesFlow shared list and detail

- [ ] 10.1 Write failing tests: `DefaultNoteListViewModel.refresh()` on Shared segment calls `flushPending` then local `listSharedNotes`; segment switch reloads local summaries only (`DefaultNoteListViewModelSharedTests`)
- [ ] 10.2 Confirm list VM behavior against local repo (adjust only if tests fail); make tests pass
- [ ] 10.3 Write failing tests: `DefaultSharedNoteDetailViewModel.load()` does not call `listSharedNotes()`; owner email from local index; decrypt via `readSharedNote` (`DefaultSharedNoteDetailViewModelLoadTests`)
- [ ] 10.4 Update shared detail VM owner-email lookup; make tests pass

## 11. Logout and composition verification

- [ ] 11.1 Write failing tests: logout reset removes `shared_notes` data and `shared/` directory; NotesFlow still receives `LocalNoteRepository` (not composite) with working shared list after sync (`LogoutResetSharedCacheTests`, `AppCompositionSharedNotesTests`)
- [ ] 11.2 Extend logout wipe for shared cache if needed; verify composition wiring; make tests pass

## 12. Manual smoke

- [ ] 12.1 Manual smoke: share note to recipient → Shared segment shows entry after refresh → open detail offline after first sync → attachments hydrate → delete removes from list and server
