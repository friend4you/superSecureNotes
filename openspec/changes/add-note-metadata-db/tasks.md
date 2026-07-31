## 1. NoteRepositoryProtocol — StoredNote and protocol changes

- [ ] 1.1 Write failing tests: `NoteSyncState` equatable; `StoredNote` equatable; `NoteRepositoryError.databaseNotOpen` equatable (`Packages/NoteRepository/Tests/NoteRepositoryProtocolTests/StoredNoteTests.swift`, `NoteRepositoryErrorTests.swift`)
- [ ] 1.2 Add `NoteSyncState`, `StoredNote`, `databaseNotOpen` error, and updated `NoteRepository` protocol (`openDatabase`, `closeDatabase`, `writeNote(_:)`, `readNote` → `StoredNote`); make tests pass

## 2. SecureCrypto — payload-only format

- [ ] 2.1 Write failing tests: payload file roundtrip; reject empty payload (`Packages/SecureCrypto/Tests/SecureCryptoTests/Note/NotePayloadFileTests.swift`)
- [ ] 2.2 Implement payload-only file helpers in `Packages/SecureCrypto/Sources/SecureCrypto/Note/`; make tests pass
- [ ] 2.3 Remove `LocalNoteBody.swift`, `LocalNoteBodyTests.swift`, and `NoteMetadata.fromLocalNoteBody`; update any remaining references; ensure wire-format tests still pass

## 3. NoteRepository — GRDB + SQLCipher setup

- [ ] 3.1 Add GRDB + SQLCipher dependencies to `Packages/NoteRepository/Package.swift`
- [ ] 3.2 Write failing tests: HKDF database key derivation is deterministic and distinct from raw UDK (`Packages/NoteRepository/Tests/NoteRepositoryTests/NotesDatabaseKeyTests.swift`)
- [ ] 3.3 Implement UDK → database passphrase HKDF helper; make tests pass

## 4. NoteRepository — NoteDatabase

- [ ] 4.1 Write failing tests: open with correct passphrase succeeds; wrong passphrase fails; schema creates `notes` table; close prevents queries (`Packages/NoteRepository/Tests/NoteRepositoryTests/NoteDatabaseTests.swift`)
- [ ] 4.2 Implement `NoteDatabase` actor with GRDB SQLCipher open/close and schema migration; make tests pass

## 5. NoteRepository — LocalNoteRepository rewrite

- [ ] 5.1 Write failing tests: open/close lifecycle; write/read `StoredNote` roundtrip; `listNotes` from DB; delete removes row and payload dir; `noteNotFound`; `corruptNote` when row/file mismatch; `databaseNotOpen` before open; `validationError` on empty payload; payload file has no metadata header; atomic directory replace; `syncState` persisted (`Packages/NoteRepository/Tests/NoteRepositoryTests/LocalNoteRepositoryTests.swift`)
- [ ] 5.2 Rewrite `LocalNoteRepository` with DB + `notes/{uuid}/payload` storage; make tests pass

## 6. NoteRepository — NetworkNoteRepository update

- [ ] 6.1 Write failing tests: open/close no-op; write assembles wire blob; read parses to `StoredNote` with `syncState: .synced` (`Packages/NoteRepository/Tests/NoteRepositoryTests/NetworkNoteRepositoryStoredNoteTests.swift`)
- [ ] 6.2 Update `NetworkNoteRepository` and existing network tests for new protocol; make tests pass

## 7. NotesFlow — ViewModel updates

- [ ] 7.1 Write failing tests: `DefaultCreateNoteViewModel.save` writes `StoredNote` with `pendingSync`; `DefaultNoteDetailViewModel.load` reads `StoredNote` and decrypts; `save` writes `StoredNote` with `pendingSync` (`Packages/NotesFlow/Tests/NotesFlowTests/DefaultCreateNoteViewModelTests.swift`, `DefaultNoteDetailViewModelTests.swift`)
- [ ] 7.2 Update `DefaultCreateNoteViewModel` and `DefaultNoteDetailViewModel` to use structured repository API; make tests pass
- [ ] 7.3 Update `NotesFlow` test mocks (`MockNoteRepository`) for new protocol; make all NotesFlow tests pass

## 8. App wiring — database lifecycle

- [ ] 8.1 Write failing tests: `LockCoordinator.lock` calls `closeDatabase` before `vaultSession.clear`; `LogoutReset.perform` calls `closeDatabase` before clear (`superSecureNotesTests/LockCoordinatorTests.swift`, `Packages/AuthFlow/Tests/AuthFlowProtocolTests/LogoutResetTests.swift`)
- [ ] 8.2 Update `LockCoordinator`, `LogoutReset`, and call sites to accept and use `noteRepository`; make tests pass
- [ ] 8.3 Write failing tests: unlock/login/register view models call `openDatabase` after successful `establish` (`Packages/AuthFlow/Tests/AuthFlowProtocolTests/ViewModels/NoteDatabaseOpenTests.swift`)
- [ ] 8.4 Inject `noteRepository` into auth view models; call `openDatabase` with HKDF-derived passphrase after `establish`; update `AppComposition`; make tests pass
- [ ] 8.5 Update `AppCompositionTests`, `LogoutFlowTests`, and other composition tests for new protocol and lifecycle; make tests pass

## 9. Manual verification

- [ ] 9.1 Wipe app data; unlock → create note → verify `notes.db` exists and `notes/{uuid}/payload` has no plaintext title
- [ ] 9.2 Lock app → unlock → note list and detail still work
- [ ] 9.3 Logout → verify database closed; login again → notes empty (fresh) or wipe confirmed
