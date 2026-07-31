## Context

`LocalNoteRepository` persists notes as split files under `Application Support/superSecureNotes/notes/{uuid}/`: a `note` file (SSNT header + plaintext metadata + encrypted payload) and a `fek` file (UDK-wrapped FEK). `listNotes()` scans all directories and parses plaintext metadata from each `note` file. ViewModels produce and consume full wire-format `.note` blobs via `assembleNoteFile` / `parseNoteFile`.

Exploration decisions (confirmed):

- Metadata and `wrapped_fek` move to UDK-encrypted SQLCipher database (GRDB)
- Note files contain only encrypted payload (body + attachments)
- Plaintext metadata columns inside encrypted DB (fast list when unlocked)
- Structured `StoredNote` at repository boundary (Option B — no opaque wire blob)
- `NoteSyncState`: `pendingSync` | `synced` (two-state flag for future backend)
- DB opened explicitly after vault unlock; closed on lock and logout (Option A)
- Wire `.note` format kept in SecureCrypto for future network sync
- Payload stored as file per note (not DB BLOB)
- No migration — wipe existing local notes
- No recovery/export story
- Notes flow only reached after unlock; `listNotes()` not called while locked

## Goals / Non-Goals

**Goals:**

- `NoteRepository` protocol uses `StoredNote` instead of opaque `Data`
- `LocalNoteRepository` with GRDB + SQLCipher at `Application Support/superSecureNotes/notes.db`
- Per-note `notes/{uuid}/payload` file (encrypted payload bytes only)
- `openDatabase(passphrase:)` derives SQLCipher key via HKDF from UDK; `closeDatabase()` closes connection
- `listNotes()` queries DB; `readNote` / `writeNote` use DB row + payload file
- New/updated notes set `syncState = .pendingSync`
- Auth view models call `openDatabase` after `vaultSession.establish`
- `LockCoordinator` and `LogoutReset` call `closeDatabase` before `vaultSession.clear`
- SecureCrypto payload-only file helpers; remove `LocalNoteBody`
- Update ViewModels to structured save/load
- `NetworkNoteRepository` maps `StoredNote` ↔ wire blob (no-op `openDatabase`/`closeDatabase`)
- Strict TDD

**Non-Goals:**

- Backend sync implementation
- Migration from `note` + `fek` layout
- `NoteSummary` field expansion
- Attachment externalization (attachments stay in encrypted payload)
- Recovery/export if DB is lost
- Per-note FEK-encrypted metadata columns
- `VaultSession` protocol changes
- Composite local + network repository

## Decisions

### 1. Storage layout

```
Application Support/superSecureNotes/
  vault/vault-header.bin
  notes.db                         ← SQLCipher, key = HKDF(UDK)
  notes/{uuid}/payload             ← raw encrypted payload bytes
```

**Rationale:** DB holds index + keys; files hold large ciphertext. Matches exploration.

**Alternatives considered:**
- Payload in DB BLOB — rejected; bloats DB with attachment bytes
- Keep `fek` file — rejected; user wants FEK in DB only

### 2. SQLCipher key derivation

Derive database passphrase from UDK bytes using HKDF-SHA256 with info string `"superSecureNotes.notes.db.v1"`. Do not use raw UDK as SQLCipher key directly.

**Rationale:** Key separation; UDK remains vault master key.

### 3. Database schema

```sql
CREATE TABLE notes (
  note_id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  attachment_count INTEGER NOT NULL,
  attachments_total_size INTEGER NOT NULL,
  wrapped_fek BLOB NOT NULL,
  sync_state TEXT NOT NULL CHECK (sync_state IN ('pendingSync', 'synced'))
);
```

**Rationale:** Plaintext columns inside encrypted DB; `sync_state` ready for future backend.

### 4. Structured repository API

```swift
enum NoteSyncState: String, Sendable { case pendingSync, synced }

struct StoredNote: Sendable {
    let metadata: NoteMetadata
    let wrappedFEK: Data
    let encryptedPayload: Data
    let syncState: NoteSyncState
}

protocol NoteRepository {
    func openDatabase(passphrase: Data) async throws
    func closeDatabase() async
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> StoredNote
    func writeNote(_ note: StoredNote) async throws
    func deleteNote(noteID: UUID) async throws
}
```

`writeNote` validates `note.metadata.noteID` is consistent. New writes and updates set `syncState = .pendingSync` unless caller specifies otherwise (ViewModels always pass `pendingSync`).

**Rationale:** Option B from exploration; ViewModels own crypto; repository owns persistence.

### 5. Payload-only on-disk format

`payload` file stores raw encrypted payload bytes with no SSNT header or metadata. Optional: length validation via DB consistency check on read.

SecureCrypto helpers:

- `readNotePayloadFile(_ data: Data) -> Data` — validate non-empty, return bytes
- `writeNotePayloadFile(_ encryptedPayload: Data) -> Data` — identity or minimal magic wrapper TBD in implementation

**Rationale:** Note file is ciphertext only; metadata lives in DB.

**Alternatives considered:**
- Magic byte wrapper — may add in implementation for corruption detection; not required in v1

### 6. Retire LocalNoteBody

Remove `assembleLocalNoteBody`, `parseLocalNoteBody`, and `NoteMetadata.fromLocalNoteBody`. Keep `assembleNoteFile` / `parseNoteFile` for wire format and `NetworkNoteRepository`.

**Rationale:** Local metadata-in-file format superseded by DB.

### 7. Save ordering and atomicity

On `writeNote`:

1. Write `notes/{uuid}/payload` to `notes/{uuid}.tmp/payload`
2. Upsert DB row with `sync_state = pendingSync`
3. Atomically replace `notes/{uuid}/` directory via rename

On failure after payload write but before DB commit: orphan payload file acceptable (wipe in dev; future cleanup).

**Rationale:** Payload-first ensures ciphertext exists before index references it; sync flag supports future backend partial-state handling.

### 8. DB lifecycle (Option A)

**Open** — after successful vault unlock in `DefaultUnlockViewModel`, `DefaultLoginViewModel`, `DefaultRegisterViewModel`:

```swift
await vaultSession.establish(keys)
let udk = keys.udk
let dbKey = deriveNotesDatabaseKey(from: udk)
try await noteRepository.openDatabase(passphrase: dbKey)
```

**Close** — before `vaultSession.clear()` in `LockCoordinator.lock()` and `LogoutReset.perform()`.

**Rationale:** Explicit; auth flow controls when notes are accessible. Notes flow never reached while locked.

### 9. NetworkNoteRepository adaptation

- `openDatabase` / `closeDatabase` — no-op
- `writeNote` — assemble wire blob from `StoredNote`, PUT as today
- `readNote` — GET wire blob, parse into `StoredNote` with `syncState = .synced`
- `listNotes` — unchanged (server JSON index)

**Rationale:** Protocol conformance without network DB; wire format preserved for API.

### 10. Errors

Add `NoteRepositoryError.databaseNotOpen` when DB methods called before `openDatabase`.

Update `corruptNote`: DB row exists but `payload` file missing, or `payload` exists but no DB row, or `wrapped_fek` empty.

**Rationale:** Clear failure modes for split storage.

### 11. No migration

Delete app data or reinstall. Old `note` + `fek` directories are not read.

**Rationale:** User confirmed wipe.

### 12. GRDB + SQLCipher

Add dependencies to `NoteRepository` `Package.swift`:

- `grdb.swift` with SQLCipher variant (or `GRDB` + `SQLCipher` product)

Use `DatabaseQueue` with `PRAGMA key` at open.

**Rationale:** Standard iOS encrypted SQLite stack.

## Risks / Trade-offs

- **[DB is source of truth for metadata]** → Losing `notes.db` loses titles/dates; acceptable per decision; no recovery
- **[Orphan payload files after failed write]** → Acceptable in v1; optional cleanup later
- **[GRDB + SQLCipher dependency]** → Adds build complexity; standard trade-off for encrypted SQLite
- **[Protocol breaking change]** → Touches ViewModels, both repository implementations, all tests; necessary for clean API
- **[HKDF key derivation]** → Must be stable across app versions; version suffix in info string allows future rotation
- **[NetworkNoteRepository unused locally]** → Still must compile and conform

## Migration Plan

1. Add GRDB + SQLCipher to `NoteRepository` package
2. Add `StoredNote`, `NoteSyncState`, protocol changes, HKDF helper
3. Implement `NoteDatabase` + rewritten `LocalNoteRepository`
4. Add SecureCrypto payload helpers; remove `LocalNoteBody`
5. Update ViewModels and auth/lock wiring
6. Update `NetworkNoteRepository`
7. Remove old tests referencing `note` + `fek` layout
8. Manual verification: unlock → create note → list → lock → unlock → note persists; verify `notes.db` encrypted and no plaintext titles in payload files

No rollback — wipe and reinstall.

## Open Questions

None — all decisions confirmed during exploration.
