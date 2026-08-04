## 1. Upload size threshold and API client — single PUT path

- [x] 1.1 Write failing tests: `NoteUploadSizeThreshold` is `10_000_000`; `uploadNote` with assembled blob `<= threshold` sends one PUT to `/notes/{id}` and no upload-session endpoints (`NoteAPIClientWriteNoteTests`, `NetworkNoteRepositoryWriteNoteTests`)
- [x] 1.2 Add threshold constant; ensure existing PUT path unchanged for sub-threshold blobs; make tests pass

## 2. Chunked upload API client

- [x] 2.1 Write failing tests: over-threshold `uploadNote` calls `POST /notes/{id}/uploads` with `{ totalSize }`, then chunk PUTs for indices `0..<totalChunks`, then `POST .../complete` with optional `ifMatch`; complete parses `{ syncState, updatedAt, etag }` (`NoteAPIClientChunkedUploadTests`)
- [x] 2.2 Implement `initUpload`, `uploadChunk`, `completeUpload` on `NoteAPIClient`; branch in `NetworkNoteRepository.uploadNote`; make tests pass
- [x] 2.3 Write failing tests: failed chunk PUT is retried and previously successful chunk indices are not re-sent in the same session (`NetworkNoteRepositoryChunkedUploadTests`)
- [x] 2.4 Implement per-chunk retry loop in chunked upload helper; make tests pass

## 3. Upload session persistence

- [ ] 3.1 Write failing tests: `NotesIndexStore` persists upload session row (uploadId, wireSize, chunkSize, totalChunks, completed indices, ifMatch); survives close/reopen; deletes on successful complete (`NotesIndexStoreUploadSessionTests`)
- [ ] 3.2 Add `note_upload_sessions` schema + CRUD; migrate on open; make tests pass
- [ ] 3.3 Write failing tests: resume skips completed chunk indices; wire size mismatch deletes session and re-inits; server session not-found clears session and restarts (`LocalFirstNoteSyncServiceChunkedUploadTests`)
- [ ] 3.4 Integrate session load/save/invalidate into sync flush chunked path; make tests pass

## 4. Sync outcome events and scheduleFlush

- [ ] 4.1 Write failing tests: `NoteSyncing.scheduleFlush()` starts flush without blocking caller; `LocalFirstNoteSyncService` emits success/failure outcome per note after push attempt (`NoteSyncOutcomeTests`)
- [ ] 4.2 Add `NoteSyncOutcome`, outcome stream on sync service, and `scheduleFlush()` on protocol + `NoOp` stub; make tests pass

## 5. NotesFlow — sync on save

- [ ] 5.1 Write failing tests: `DefaultCreateNoteViewModel.save()` calls `scheduleFlush()` after successful write; `DefaultNoteDetailViewModel.save()` same (`DefaultCreateNoteViewModelTests`, `DefaultNoteDetailViewModelTests`)
- [ ] 5.2 Inject sync scheduler into create/detail view models via `NotesFlowDependencies`; make tests pass

## 6. NotesFlow — UI updates on sync outcome

- [ ] 6.1 Write failing tests: list VM reloads/patches row on successful sync outcome; detail VM sets `syncState` to synced for matching note ID; list includes new note after create return (`DefaultNoteListViewModelTests`, `DefaultNoteDetailViewModelTests`)
- [ ] 6.2 Wire outcome subscription in list/detail VMs; trigger list reload on navigation return from create; make tests pass
- [ ] 6.3 Write failing tests: `NoteListView` / `NoteDetailView` sources still expose sync indicators driven by updated VM state (`NoteListViewTests`, `NoteDetailViewTests`)
- [ ] 6.4 Adjust views if needed for navigation reload hook; make tests pass

## 7. App composition

- [ ] 7.1 Write failing tests: `NotesFlowDependencies` passes sync service with outcome stream to list/create/detail factories (`NotesFlowDependenciesTests`)
- [ ] 7.2 Wire outcome stream and sync scheduler in `AppComposition` / `NotesFlowDependencies`; make tests pass

## 8. Manual verification

- [ ] 8.1 With API on `:8000`: create small note → Pending immediately → Synced without pull-to-refresh
- [ ] 8.2 Create or upload note with wire blob `> 10 MB` → chunked path completes → Synced; kill app mid-upload → resume completes
- [ ] 8.3 Edit note during pending chunked upload → new upload session used; final content synced
