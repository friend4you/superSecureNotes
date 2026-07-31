## Why

Local notes currently store plaintext metadata (title, dates, attachment stats) in each on-disk `note` file, with wrapped FEKs in a separate `fek` file. Listing notes requires scanning every note directory and parsing file headers. Metadata is visible on disk without vault unlock, and the split-file layout couples indexing to the filesystem. Moving metadata and wrapped FEKs into a UDK-encrypted SQLCipher database — with note files containing only encrypted payloads — improves privacy, enables fast queries, and prepares a sync-flag column for future backend integration.

## What Changes

- Add `NotesIndexStore` in `NoteRepository` package — owns GRDB + SQLCipher at `Application Support/superSecureNotes/notes/notes.db` (vault-like encrypted local store)
- Add `deriveNotesDatabaseKey(from:)` in SecureCrypto — HKDF from UDK; no SQLite in SecureCrypto
- **BREAKING**: Change `NoteRepository` protocol from opaque wire `Data` blobs to structured `StoredNote` (metadata, wrapped FEK, encrypted payload, sync state)
- **BREAKING**: Remove storage lifecycle from `NoteRepository` protocol — CRUD only; no `openDatabase`/`closeDatabase` on protocol
- Replace split `note` + `fek` files with per-note `payload` file (encrypted body + attachments only)
- Auth/app layer opens `NotesIndexStore` after `vaultSession.establish`; lock and logout close it before `vaultSession.clear`
- **NotesFlow MUST NOT** open or close the notes index store — assumes unlock already completed
- Add `NoteSyncState` enum (`pendingSync`, `synced`); new and updated notes default to `pendingSync`
- Add SecureCrypto payload-only on-disk format; retire `LocalNoteBody` (metadata-in-file) helpers
- Keep wire-format `.note` assemble/parse in SecureCrypto for future network sync
- Update `DefaultCreateNoteViewModel` and `DefaultNoteDetailViewModel` to use structured repository API (CRUD only)
- Update `LockCoordinator`, `LogoutReset`, and unlock/login/register view models for `NotesIndexStore` lifecycle
- Update `NetworkNoteRepository` to conform to new protocol (maps `StoredNote` ↔ wire blob; no local index store)
- **BREAKING**: No migration from `note` + `fek` layout; wipe existing local notes
- Refactor interim step-1 `openDatabase` on `NoteRepository` to `NotesIndexStore` lifecycle
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

<!-- No new top-level packages; NotesIndexStore lives in NoteRepository package -->

### Modified Capabilities

- `note-repository`: `NotesIndexStore`, structured `StoredNote` API, SQLCipher index, payload-file storage, `NoteSyncState`; `NoteRepository` CRUD only (no lifecycle); updated `LocalNoteRepository` and `NetworkNoteRepository`
- `secure-crypto`: `deriveNotesDatabaseKey`, payload-only on-disk format; remove local note body format; keep wire `.note` format
- `notes-flow`: ViewModels save/load via `StoredNote`; explicit prohibition on index-store lifecycle calls
- `session-lock`: Close `NotesIndexStore` on lock and logout before clearing vault session
- `app-navigation`: Open `NotesIndexStore` after successful vault unlock in auth view models; wire `notesIndexStore` into auth/lock/logout; NotesFlow not involved in lifecycle

## Impact

- `Packages/NoteRepository/` — `NotesIndexStore`, GRDB + SQLCipher, `StoredNote`, `NoteSyncState`, rewritten `LocalNoteRepository`, updated `NetworkNoteRepository`, protocol changes, tests
- `Packages/SecureCrypto/` — `deriveNotesDatabaseKey`, payload-only file helpers; remove `LocalNoteBody`; keep `assembleNoteFile` / `parseNoteFile`
- `Packages/NotesFlow/` — `DefaultCreateNoteViewModel`, `DefaultNoteDetailViewModel`, tests; no lifecycle dependencies
- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — unlock/login/register open `NotesIndexStore` after `establish`
- `superSecureNotes/LockCoordinator.swift` — `notesIndexStore.close()` on lock
- `Packages/AuthFlow/Sources/AuthFlowProtocol/LogoutReset.swift` — `notesIndexStore.close()` on logout
- `superSecureNotes/AppComposition.swift` — wire `notesIndexStore` to auth and lock flows; inject `noteRepository` into NotesFlow only for CRUD
- Out of scope: backend sync implementation, migration from old layout, `NoteSummary` field expansion, attachment externalization, recovery/export, `VaultSession` protocol changes
