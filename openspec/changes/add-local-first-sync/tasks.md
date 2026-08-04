## 1. NoteSyncState and NoteSummary

- [x] 1.1 Write failing tests: `pendingDelete` equatable and distinct from `synced`/`pendingSync`; `NoteSummary` includes `syncState` (`Packages/NoteRepository/Tests/NoteRepositoryProtocolTests/StoredNoteTests.swift`, `NoteSummaryTests.swift`)
- [x] 1.2 Add `NoteSyncState.pendingDelete` and `NoteSummary.syncState`; update call sites that construct `NoteSummary`; make tests pass

## 2. NotesIndexStore etag and pendingDelete

- [x] 2.1 Write failing tests: index row roundtrip preserves `etag`; `sync_state` accepts `pendingDelete`; list/query helpers return sync state (`Packages/NoteRepository/Tests/NoteRepositoryTests/NotesIndexStoreTests.swift`)
- [x] 2.2 Extend `NotesIndexStore` schema/CHECK + upsert/fetch for `etag` and `pendingDelete`; migrate existing DBs safely; make tests pass

## 3. LocalNoteRepository list/delete sync semantics

- [x] 3.1 Write failing tests: `listNotes` returns `syncState` on summaries; notes with `pendingDelete` (or outbox-hidden deletes) are omitted; delete enqueues remote-delete intent while removing visible local note (`Packages/NoteRepository/Tests/NoteRepositoryTests/LocalNoteRepositoryTests.swift`)
- [x] 3.2 Implement list filtering + delete enqueue/outbox behavior on `LocalNoteRepository`; make tests pass

## 4. Network note PUT 200 + etag

- [x] 4.1 Write failing tests: `NoteAPIClient.writeNote` succeeds on HTTP 200 with `{syncState,updatedAt,etag}` body; still maps 401; rejects unexpected codes (`Packages/NoteRepository/Tests/NoteRepositoryTests/NoteAPIClientWriteNoteTests.swift`)
- [x] 4.2 Update `NoteAPIClient.writeNote` expected success codes and response parsing; plumb etag to `NetworkNoteRepository` callers; make tests pass
- [x] 4.3 Write failing tests: optional `If-Match` header sent when etag provided (`NoteAPIClientWriteNoteTests`)
- [x] 4.4 Add If-Match support to write API; make tests pass

## 5. Sync orchestrator — push and LWW

- [x] 5.1 Write failing tests: flush uploads `pendingSync` notes via network client; on 200 sets local `.synced` + etag; create/save path does not await network (`superSecureNotesTests/` or package tests for sync service)
- [x] 5.2 Implement sync orchestrator push path against injectable local + network deps; make tests pass
- [x] 5.3 Write failing tests: on 409, compare `updatedAt` — local newer retries upload; remote newer overwrites local as `.synced` (LWW scenarios)
- [x] 5.4 Implement conflict handling; make tests pass
- [x] 5.5 Write failing tests: flush performs enqueued remote DELETE; failure keeps delete pending without restoring list visibility
- [x] 5.6 Implement remote delete flush; make tests pass

## 6. Sync orchestrator — empty-local pull and vault push

- [x] 6.1 Write failing tests: when local vault missing after auth, pull vault header + list/download notes into local as `.synced`; when local vault exists, skip full pull
- [x] 6.2 Implement empty-local pull; make tests pass
- [x] 6.3 Write failing tests: after local vault write on register, fire-and-forget `PUT /vault/header`; register success does not depend on upload completion
- [x] 6.4 Implement vault header push hook; make tests pass

## 7. Retry triggers and composition

- [x] 7.1 Write failing tests: unlock-online, note-list refresh, and network-online transition invoke flush (`AuthFlow` / `NotesFlow` / app tests as appropriate)
- [x] 7.2 Wire flush calls into unlock, `DefaultNoteListViewModel.refresh`, and reachability observer; make tests pass
- [x] 7.3 Write failing tests: `AppDependencies` uses `http://localhost:8000/v1`, always `NetworkAuthRepository`, no stub gate (`superSecureNotesTests/AppDependenciesTests.swift`)
- [x] 7.4 Update `AppDependencies` base URL, remove `StubBackendConfiguration` / `InMemoryAuthRepository` wiring, construct network clients + sync orchestrator; make tests pass
- [x] 7.5 Delete stub backend types/scheme argument and rewrite or remove obsolete stub-only tests

## 8. NotesFlow sync indicators

- [x] 8.1 Write failing tests: note list source/UI exposes pending vs synced indicator from `NoteSummary.syncState`; detail view model exposes `syncState` after load (`Packages/NotesFlow/Tests/...`)
- [x] 8.2 Implement list + detail sync indicators and localization strings; make tests pass
- [x] 8.3 Write failing tests: `refresh()` invokes sync flush then reloads local list
- [x] 8.4 Wire refresh → flush; make tests pass

## 9. Manual verification

- [ ] 9.1 With API on `:8000`: register → create note → pending then synced indicator; kill app → unlock → note still local
- [ ] 9.2 Delete note → disappears immediately; confirm remote DELETE via API/docs after flush
- [ ] 9.3 Fresh install / cleared local data → login existing account → vault + notes pulled and usable offline afterward
