## 1. NoteRepositoryProtocol — StoredNote and protocol changes

- [x] 1.1 Write failing tests: `NoteSyncState` equatable; `StoredNote` equatable; `NoteRepositoryError.databaseNotOpen` equatable (`Packages/NoteRepository/Tests/NoteRepositoryProtocolTests/StoredNoteTests.swift`, `NoteRepositoryErrorTests.swift`)
- [x] 1.2 Add `NoteSyncState`, `StoredNote`, `databaseNotOpen` error, and updated `NoteRepository` protocol (`writeNote(_:)`, `readNote` → `StoredNote`); make tests pass (interim: includes `openDatabase`/`closeDatabase` on protocol)
- [x] 1.3 Refactor per updated design: introduce `NotesIndexStore` with `open`/`close`; remove lifecycle from `NoteRepository` protocol; `LocalNoteRepository` injects `NotesIndexStore`; update protocol and repository tests

## 2. SecureCrypto — payload-only format and DB key derivation

- [x] 2.1 Write failing tests: payload file roundtrip; reject empty payload (`Packages/SecureCrypto/Tests/SecureCryptoTests/Note/NotePayloadFileTests.swift`)
- [x] 2.2 Implement payload-only file helpers in `Packages/SecureCrypto/Sources/SecureCrypto/Note/`; make tests pass
- [x] 2.3 Write failing tests: `deriveNotesDatabaseKey` deterministic and distinct from raw UDK (`Packages/SecureCrypto/Tests/SecureCryptoTests/NotesDatabaseKeyTests.swift`)
- [x] 2.4 Implement `deriveNotesDatabaseKey(from:)` in SecureCrypto; make tests pass
- [x] 2.5 Remove `LocalNoteBody.swift`, `LocalNoteBodyTests.swift`, and `NoteMetadata.fromLocalNoteBody`; update any remaining references; ensure wire-format tests still pass

## 3. NoteRepository — GRDB + SQLCipher setup

- [x] 3.1 Add GRDB + SQLCipher dependencies to `Packages/NoteRepository/Package.swift`

## 4. NoteRepository — NotesIndexStore

- [x] 4.1 Write failing tests: open with correct passphrase succeeds; wrong passphrase fails; schema creates `notes` table; close prevents queries; `isOpen` reflects state (`Packages/NoteRepository/Tests/NoteRepositoryTests/NotesIndexStoreTests.swift`)
- [x] 4.2 Implement `NotesIndexStore` actor with GRDB SQLCipher open/close, schema, and index query methods; make tests pass

## 5. NoteRepository — LocalNoteRepository rewrite

- [x] 5.1 Write failing tests: write/read `StoredNote` roundtrip via open index store; `listNotes` from index store; delete removes row and payload dir; `noteNotFound`; `corruptNote` when row/file mismatch; `databaseNotOpen` when index store closed; `validationError` on empty payload; payload file has no metadata header; atomic directory replace; `syncState` persisted (`Packages/NoteRepository/Tests/NoteRepositoryTests/LocalNoteRepositoryTests.swift`)
- [x] 5.2 Rewrite `LocalNoteRepository` with injected `NotesIndexStore` + `notes/{uuid}/payload` storage; make tests pass

## 6. NoteRepository — NetworkNoteRepository update

- [ ] 6.1 Write failing tests: write assembles wire blob; read parses to `StoredNote` with `syncState: .synced`; no lifecycle methods on protocol (`Packages/NoteRepository/Tests/NoteRepositoryTests/NetworkNoteRepositoryStoredNoteTests.swift`)
- [ ] 6.2 Update `NetworkNoteRepository` and existing network tests; remove lifecycle methods; make tests pass

## 7. NotesFlow — ViewModel updates

- [ ] 7.1 Write failing tests: `DefaultCreateNoteViewModel.save` writes `StoredNote` with `pendingSync`; `DefaultNoteDetailViewModel.load` reads `StoredNote` and decrypts; `save` writes `StoredNote` with `pendingSync`; view models do not call index store lifecycle (`Packages/NotesFlow/Tests/NotesFlowTests/DefaultCreateNoteViewModelTests.swift`, `DefaultNoteDetailViewModelTests.swift`)
- [ ] 7.2 Update `DefaultCreateNoteViewModel` and `DefaultNoteDetailViewModel` to use structured repository API; make tests pass
- [ ] 7.3 Update `NotesFlow` test mocks (`MockNoteRepository`) for CRUD-only protocol; make all NotesFlow tests pass

## 8. App wiring — NotesIndexStore lifecycle (auth layer only)

- [x] 8.1 Write failing tests: `LockCoordinator.lock` calls `notesIndexStore.close()` before `vaultSession.clear()`; `LogoutReset.perform` calls `notesIndexStore.close()` before clear (`superSecureNotesTests/LockCoordinatorTests.swift`, `Packages/AuthFlow/Tests/AuthFlowProtocolTests/LogoutResetTests.swift`)
- [x] 8.2 Update `LockCoordinator`, `LogoutReset`, and call sites to use `notesIndexStore`; make tests pass
- [x] 8.3 Write failing tests: unlock/login/register view models call `notesIndexStore.open(passphrase:)` with `deriveNotesDatabaseKey(udk)` after successful `establish`; failed unlock does not open (`Packages/AuthFlow/Tests/AuthFlowProtocolTests/ViewModels/NotesIndexStoreOpenTests.swift`)
- [x] 8.4 Inject `notesIndexStore` into auth view models (not NotesFlow); call `open` after `establish`; update `AppComposition`; make tests pass
- [x] 8.5 Write failing test: `NotesFlowDependencies` does not receive `NotesIndexStore` (`Packages/NotesFlow/Tests/NotesFlowTests/NotesFlowDependenciesTests.swift`)
- [ ] 8.6 Update `AppCompositionTests`, `LogoutFlowTests`, and other composition tests; make tests pass

## 9. Manual verification

- [ ] 9.1 Wipe app data; unlock → create note → verify `notes/notes.db` exists and `notes/{uuid}/payload` has no plaintext title
- [ ] 9.2 Lock app → unlock → note list and detail still work
- [ ] 9.3 Logout → verify index store closed; login again → notes empty (fresh) or wipe confirmed
