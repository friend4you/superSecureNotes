## Context

`AppDependencies` wires `vaultRepository` to `LocalVaultRepository` (local disk). Network vault access lives inside `LocalFirstNoteSyncService` via `NetworkVaultRepository`.

Current auth behavior:

| Step | Register | Login |
|------|----------|-------|
| Vault write/read | Local `writeHeader` | Local `readHeader` only |
| Network vault | `scheduleVaultHeaderUpload` (async, `try?`) | Not called |
| Notes pull | No | No |

`pullCatalogIfLocalVaultMissing()` bundles vault fetch + `importRemoteNotes()`, but note import requires an open SQLCipher index (`LocalNoteRepository.requireOpen()`). Auth opens the index only after unlock in `NotesIndexStoreLifecycle.openAfterEstablish`.

## Goals / Non-Goals

**Goals:**

- Successful register guarantees vault header exists on backend
- Fresh login (`hasLocalSetup == false`) restores vault header and owned notes from backend when local vault file is missing
- Correct ordering: header pull → unlock → index open → notes pull
- TDD: auth and sync tests drive implementation

**Non-Goals:**

- Full catalog re-pull on every unlock (unchanged — unlock uses Keychain header)
- Logout wiping local vault file (logout still clears Keychain; local file may remain — login on same device without wipe may read local file and skip pull; acceptable for v1)
- Retry vault upload on later unlock if register succeeded (register fail-fast makes this unnecessary)
- Changing note push/sync behavior from `add-local-first-sync` / `add-chunked-note-upload`

## Decisions

### 1. Split pull API on sync orchestrator

Replace monolithic pull with two methods on `NoteSyncing` / `LocalFirstNoteSyncService`:

```
pullVaultHeaderIfLocalMissing() async throws -> Data?
  - if local vault file exists → return nil
  - else GET /vault/header → write local → return header bytes

pullRemoteNotesCatalog() async throws
  - GET /notes → for each id GET blob → importSyncedNote (requires open index)
```

Deprecate or reimplement `pullCatalogIfLocalVaultMissing()` as a test helper or thin wrapper that calls both (only valid when index already open — keep for existing tests or update tests).

**Rationale:** Matches spec ordering; avoids `requireOpen()` failure on fresh login.

### 2. Register: await vault upload; fail entire register on error

Flow:

```
auth register OK
createVault + writeHeader(local)
await PUT /vault/header          ← new: blocking, throws on failure
  on failure:
    clear auth session (logout/clearSession best-effort)
    throw → UI failure, hasLocalSetup stays false
unlock + open index + saveSetup
```

Replace `scheduleVaultHeaderUpload` on register path with `uploadVaultHeader` await (or new `uploadVaultHeaderOrThrow`). Keep `scheduleVaultHeaderUpload` for non-auth retry use if needed later.

**Rationale:** User explicitly requires register failure when backend has no vault; enables reliable fresh login on another device.

**Alternative rejected:** Fire-and-forget + retry on unlock — leaves window where account exists but vault missing.

### 3. Login: orchestrate pull via `NoteSyncing`

After `authRepository.login`:

```
if let pulled = try await noteSync.pullVaultHeaderIfLocalMissing() {
    headerData = pulled
} else {
    headerData = try await vaultRepository.readHeader()
}
unlockVault(headerData, password)
openAfterEstablish(...)
try await noteSync.pullRemoteNotesCatalog()   // no-op if nothing remote / already local
saveSetup(..., vaultHeader: headerData)
```

Inject `noteSync: NoteSyncing` into `DefaultLoginViewModel` via `AuthFlowDependencies` (same instance as register/unlock).

**Rationale:** Reuses network clients and import logic; keeps ViewModels off `NetworkVaultRepository` directly.

### 4. Orphan auth user on failed PUT

If `POST /auth/register` succeeds but `PUT /vault/header` fails, call `authRepository.logout()` or `clearSession()` before surfacing register failure.

**Rationale:** Reduces orphan accounts; user can retry register. If logout fails, still show register failure — manual cleanup acceptable for v1.

### 5. Remote vault 404 on login

When local vault missing and `GET /vault/header` returns `header_not_found`, map to existing `AuthFlowError.vaultNotFound` (user should register, not login).

## Risks / Trade-offs

- **[Register requires network]** → Already gated for first setup; aligned with fail-fast upload
- **[PUT fails after register creates user]** → Mitigated by session cleanup attempt; 409 on re-register if cleanup failed
- **[Logout leaves local vault file]** → Same-device login after logout may skip server pull; document as v1 limitation
- **[Large note catalog on login]** → Blocks login until import completes; acceptable for v1; progress UI out of scope
- **[Breaking vs add-local-first-sync spec]** → Explicit MODIFIED delta in this change's `local-first-sync` spec

## Migration Plan

1. Add sync API split + tests
2. Change register to await upload + rollback
3. Wire login pull sequence
4. Update/register tests; manual: register → delete app → login → notes visible
5. Archive/sync specs when change completes

Rollback: revert auth wiring; register returns to fire-and-forget (prior behavior).

## Open Questions

None — exploration decisions captured above.
