## Context

`LocalNoteRepository` persists notes as split files under `Application Support/superSecureNotes/notes/{uuid}/`: a `note` file (SSNT header + plaintext metadata + encrypted payload) and a `fek` file (UDK-wrapped FEK). `listNotes()` scans all directories and parses plaintext metadata from each `note` file. ViewModels produce and consume full wire-format `.note` blobs via `assembleNoteFile` / `parseNoteFile`.

Exploration decisions (confirmed):

- Metadata and `wrapped_fek` move to UDK-encrypted SQLCipher database (GRDB)
- Note files contain only encrypted payload (body + attachments)
- Plaintext metadata columns inside encrypted DB (fast list when unlocked)
- Structured `StoredNote` at repository boundary (Option B — no opaque wire blob)
- `NoteSyncState`: `pendingSync` | `synced` (two-state flag for future backend)
- Notes index store opened by auth/app layer after vault unlock; closed on lock/logout — parallel to vault header unlock, not inside NotesFlow
- Wire `.note` format kept in SecureCrypto for future network sync
- Payload stored as file per note (not DB BLOB)
- No migration — wipe existing local notes
- No recovery/export story
- Notes flow only reached after unlock; `listNotes()` not called while locked
- NotesFlow MUST NOT open or close encrypted local stores

## Goals / Non-Goals

**Goals:**

- `NotesIndexStore` actor owns SQLCipher DB lifecycle and note-index queries (vault-like local encrypted store)
- `NoteRepository` protocol: CRUD only (`listNotes`, `readNote`, `writeNote`, `deleteNote`) — no `openDatabase`/`closeDatabase`
- `LocalNoteRepository` uses injected `NotesIndexStore` + payload files
- `deriveNotesDatabaseKey(from: SymmetricKey)` in SecureCrypto (HKDF from UDK)
- Per-note `notes/{uuid}/payload` file (encrypted payload bytes only)
- Auth view models open `NotesIndexStore` after `vaultSession.establish`
- `LockCoordinator` and `LogoutReset` close `NotesIndexStore` before `vaultSession.clear`
- NotesFlow ViewModels call `NoteRepository` CRUD only; never touch index store lifecycle
- SecureCrypto payload-only file helpers; remove `LocalNoteBody`
- `NetworkNoteRepository` maps `StoredNote` ↔ wire blob; no local index store
- Strict TDD

**Non-Goals:**

- SQLCipher/GRDB inside SecureCrypto package
- Opening notes index from NotesFlow or note ViewModels
- Auto-open index store inside `LocalNoteRepository` on first CRUD call
- `VaultSession` protocol changes (no DB connection on `establish`/`clear`)
- Backend sync implementation
- Migration from `note` + `fek` layout
- Recovery/export if DB is lost

## Decisions

### 1. Layered architecture (vault analogy)

```
┌─────────────────────────────────────────────────────────────────┐
│  AUTH / APP LAYER                                               │
│  unlock → establish(session) → notesIndexStore.open(udk)        │
│  lock/logout → notesIndexStore.close() → session.clear()          │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
  VaultRepository      NotesIndexStore     VaultSession
  (vault-header.bin)   (notes.db)          (UDK in memory)
         │                   │
         └──────── SecureCrypto: unlock, HKDF, encrypt ──────────┘

┌─────────────────────────────────────────────────────────────────┐
│  NOTES FLOW (feature)                                           │
│  listNotes / readNote / writeNote — assumes store already open  │
│  NEVER calls notesIndexStore.open/close                         │
└────────────────────────────┬────────────────────────────────────┘
                             ▼
                      NoteRepository (CRUD)
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       NotesIndexStore                 payload files
       (metadata + wrapped_fek)        (ciphertext only)
```

**Rationale:** Same unlock moment as vault; feature flows stay ignorant of storage lifecycle. Mirrors `VaultRepository` + `VaultSession` separation.

**Alternatives considered:**
- `openDatabase` on `NoteRepository` protocol — rejected; exposes lifecycle on CRUD API; tempts misuse from NotesFlow; awkward for `NetworkNoteRepository`
- Auto-open inside `LocalNoteRepository` — rejected; hides unlock contract
- DB inside `VaultSession` — rejected; couples session to GRDB; out of scope for VaultSession changes

### 2. Storage layout

```
Application Support/superSecureNotes/
  vault/vault-header.bin
  notes/notes.db                   ← SQLCipher, key = HKDF(UDK)
  notes/{uuid}/payload           ← raw encrypted payload bytes
```

**Rationale:** `notes/` directory groups index DB and payload files. DB holds index + keys; files hold large ciphertext.

### 3. SQLCipher key derivation (SecureCrypto)

```swift
func deriveNotesDatabaseKey(from udk: SymmetricKey) -> Data
// HKDF-SHA256, info: "superSecureNotes.notes.db.v1"
```

Lives in SecureCrypto. `NotesIndexStore.open(passphrase:)` receives derived key bytes. SecureCrypto does not open SQLite.

**Rationale:** Crypto primitive in crypto module; storage in repository module.

### 4. NotesIndexStore

```swift
protocol NotesIndexStoreProtocol: Sendable {
    var isOpen: Bool { get }
    func open(passphrase: Data) async throws
    func close() async
    // internal query methods used by LocalNoteRepository
}
```

Public to app/auth layer for lifecycle. `LocalNoteRepository` depends on it for index CRUD. Throws `NotesIndexStoreError.notOpen` (or `NoteRepositoryError.databaseNotOpen` mapped at repository boundary) when used before open.

**Rationale:** Vault-like encrypted persistence separate from note CRUD protocol.

### 5. NoteRepository protocol (CRUD only)

```swift
protocol NoteRepository {
    func listNotes() async throws -> [NoteSummary]
    func readNote(noteID: UUID) async throws -> StoredNote
    func writeNote(_ note: StoredNote) async throws
    func deleteNote(noteID: UUID) async throws
}
```

No lifecycle methods. `LocalNoteRepository` requires open `NotesIndexStore` (injected); propagates `databaseNotOpen` when store closed. `NetworkNoteRepository` has no index store.

**Rationale:** NotesFlow depends only on CRUD; cannot accidentally open DB.

### 6. Database schema

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

### 7. Payload-only on-disk format

`payload` file stores raw encrypted payload bytes with no SSNT header or metadata. SecureCrypto helpers for validate/read/write payload bytes.

### 8. Retire LocalNoteBody

Remove `assembleLocalNoteBody`, `parseLocalNoteBody`, `NoteMetadata.fromLocalNoteBody`. Keep wire format helpers.

### 9. Save ordering and atomicity

On `writeNote`:

1. Write `notes/{uuid}/payload` to temp directory
2. Upsert index row via `NotesIndexStore`
3. Atomically replace `notes/{uuid}/` directory via rename

### 10. Unlock lifecycle (auth/app layer only)

**Open** — in `DefaultUnlockViewModel`, `DefaultLoginViewModel`, `DefaultRegisterViewModel` after `vaultSession.establish`:

```swift
await vaultSession.establish(keys)
let dbKey = deriveNotesDatabaseKey(from: keys.udk)
try await notesIndexStore.open(passphrase: dbKey)
// then navigate to notes
```

**Close** — in `LockCoordinator.lock()` and `LogoutReset.perform()` before `vaultSession.clear()`:

```swift
await notesIndexStore.close()
await vaultSession.clear()
```

**NotesFlow:** never calls `notesIndexStore.open` or `close`. Navigation to notes only occurs after auth unlock completes both `establish` and `open`.

### 11. NetworkNoteRepository

Maps `StoredNote` ↔ wire blob. No `NotesIndexStore`. Unchanged list endpoint.

### 12. Errors

`NoteRepositoryError.databaseNotOpen` when `LocalNoteRepository` CRUD called while `NotesIndexStore` is closed.

### 13. Interim step-1 refactor

Step 1 introduced `openDatabase`/`closeDatabase` on `NoteRepository` as interim wiring. Implementation SHALL be refactored to `NotesIndexStore` lifecycle before task 8 (auth wiring). Remove lifecycle from `NoteRepository` protocol.

### 14. GRDB + SQLCipher

Dependency on `NoteRepository` package only (`NotesIndexStore` implementation).

## Risks / Trade-offs

- **[DB is source of truth for metadata]** → No recovery; acceptable per decision
- **[Two types to wire in AppComposition]** → `notesIndexStore` for auth/lock; `noteRepository` for NotesFlow — clearer boundaries than lifecycle on repository protocol
- **[Interim protocol has lifecycle]** → Refactor task 1.3 before auth wiring
- **[NotesFlow assumes store open]** → Defensive `databaseNotOpen` if auth wiring bug; should not happen in normal navigation

## Migration Plan

1. Refactor step-1 interim: `NotesIndexStore` + remove lifecycle from `NoteRepository` protocol
2. Add GRDB + SQLCipher; implement `NotesIndexStore`
3. Add SecureCrypto `deriveNotesDatabaseKey` + payload helpers; remove `LocalNoteBody`
4. Rewrite `LocalNoteRepository` with index store + payload files
5. Update ViewModels (CRUD only)
6. Wire auth/lock/logout to `NotesIndexStore`
7. Manual verification

## Open Questions

None.
