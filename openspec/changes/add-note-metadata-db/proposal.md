## Why

Local notes currently store plaintext metadata (title, dates, attachment stats) in each on-disk `note` file, with wrapped FEKs in a separate `fek` file. Listing notes requires scanning every note directory and parsing file headers. Metadata is visible on disk without vault unlock, and the split-file layout couples indexing to the filesystem. Moving metadata and wrapped FEKs into a UDK-encrypted SQLCipher database — with note files containing only encrypted payloads — improves privacy, enables fast queries, and prepares a sync-flag column for future backend integration.

## What Changes

- Add GRDB + SQLCipher dependency to `NoteRepository`; store note metadata and `wrapped_fek` in `Application Support/superSecureNotes/notes.db`
- **BREAKING**: Change `NoteRepository` protocol from opaque wire `Data` blobs to structured `StoredNote` (metadata, wrapped FEK, encrypted payload, sync state)
- Replace split `note` + `fek` files with per-note `payload` file (encrypted body + attachments only)
- Add `openDatabase(passphrase:)` and `closeDatabase()` lifecycle methods; auth flow opens DB after vault unlock; lock and logout close DB
- Add `NoteSyncState` enum (`pendingSync`, `synced`); new and updated notes default to `pendingSync`
- Add SecureCrypto payload-only on-disk format; retire `LocalNoteBody` (metadata-in-file) helpers
- Keep wire-format `.note` assemble/parse in SecureCrypto for future network sync (unused locally)
- Update `DefaultCreateNoteViewModel` and `DefaultNoteDetailViewModel` to use structured repository API
- Update `LockCoordinator`, `LogoutReset`, and unlock/login/register view models for DB lifecycle
- Update `NetworkNoteRepository` to conform to new protocol (maps `StoredNote` ↔ wire blob at network boundary)
- **BREAKING**: No migration from `note` + `fek` layout; wipe existing local notes
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

<!-- No new top-level packages -->

### Modified Capabilities

- `note-repository`: Structured `StoredNote` API, SQLCipher database, payload-file storage, `openDatabase`/`closeDatabase`, `NoteSyncState`, updated `LocalNoteRepository` and `NetworkNoteRepository`
- `secure-crypto`: Payload-only on-disk format; remove local note body format (metadata-in-file); keep wire `.note` format
- `notes-flow`: ViewModels save/load via `StoredNote` instead of wire blob assembly
- `session-lock`: Close note database on lock and logout before clearing vault session
- `app-navigation`: Open note database after successful vault unlock in auth view models; wire `noteRepository` into unlock/login/register flows

## Impact

- `Packages/NoteRepository/` — GRDB + SQLCipher dependency, `StoredNote`, `NoteSyncState`, `NoteDatabase`, rewritten `LocalNoteRepository`, updated `NetworkNoteRepository`, protocol and error changes, tests
- `Packages/SecureCrypto/` — payload-only file helpers; remove `LocalNoteBody`; keep `assembleNoteFile` / `parseNoteFile`
- `Packages/NotesFlow/` — `DefaultCreateNoteViewModel`, `DefaultNoteDetailViewModel`, tests
- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — unlock/login/register view models call `openDatabase` after `establish`
- `superSecureNotes/LockCoordinator.swift` — `closeDatabase` on lock
- `Packages/AuthFlow/Sources/AuthFlowProtocol/LogoutReset.swift` — `closeDatabase` on logout
- `superSecureNotes/AppComposition.swift` — pass `noteRepository` to auth view models
- Out of scope: backend sync implementation, migration from old layout, `NoteSummary` field expansion, attachment externalization, recovery/export
