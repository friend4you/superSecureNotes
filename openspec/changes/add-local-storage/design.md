## Context

`NoteRepository` and `VaultRepository` currently expose network implementations (`NetworkNoteRepository`, `NetworkVaultRepository`) against `https://api.example.com/v1`. DEBUG stub file repositories (`FileNoteRepository`, `FileVaultRepository`) in the app target provide offline persistence only when `-UseStubBackend` is set. ViewModels produce and consume full wire-format `.note` blobs via `assembleNoteFile` / `parseNoteFile`. `SecureCrypto` defines the three-section `.note` format: plaintext metadata, wrapped FEK, encrypted payload.

Exploration decisions (confirmed):

- Split FEK at storage layer: two files per note (`note` + `fek`) in per-note directory
- Local on-disk layout ≠ wire format; repository reassembles full `.note` blob at API boundary
- `NoteRepository` protocol unchanged; sharing API deferred
- Storage under `Application Support/superSecureNotes/`; exclude from iCloud backup
- Prod-like local storage in all builds; `-UseStubBackend` controls auth only
- No migration from old `stub-notes/` / `stub-vault/` paths

## Goals / Non-Goals

**Goals:**

- `LocalNoteRepository` in `NoteRepository` package with split storage at `Application Support/superSecureNotes/notes/{uuid}/note` and `fek`
- `LocalVaultRepository` in `VaultRepository` package at `Application Support/superSecureNotes/vault/vault-header.bin`
- SecureCrypto helpers for local note body (metadata + encrypted payload, no FEK)
- `writeNote` accepts full wire blob → parse → split → atomic write; `readNote` merges → assemble
- `listNotes` scans note directories, parses metadata from local `note` file only
- `deleteNote` removes entire `{uuid}/` directory
- Fail with `corruptNote` when `note` exists but `fek` missing (or vice versa)
- Exclude storage directories from iCloud backup on create
- `AppDependencies` uses local repos in all builds
- Remove app-target DEBUG file stubs
- Strict TDD

**Non-Goals:**

- `NoteRepository` protocol extension (`readWrappedFEK`)
- Recipient-wrapped FEK files
- SQLite / `index.json` cache
- Migration from old combined `.note` stub files
- Composite local + network sync repository
- Keychain / session persistence
- `NotesFlow` ViewModel changes
- Changing wire-format `.note` spec

## Decisions

### 1. Storage location: Application Support

```
Application Support/superSecureNotes/
  vault/vault-header.bin
  notes/{uuid}/note
  notes/{uuid}/fek
```

**Rationale:** App-managed encrypted blobs; hidden from Files app; user cannot accidentally break split structure. Matches secure-app pattern.

**Alternatives considered:**
- Documents — rejected; user-visible, iCloud backup default, tamper risk
- Library/Caches — rejected; system may purge caches

### 2. iCloud backup exclusion

Set `NSURLIsExcludedFromBackupKey` on `superSecureNotes/` container (or vault and notes subdirectories) when creating directories.

**Rationale:** User confirmed no iCloud backup for vault or notes.

### 3. Split storage layout (per-note directory)

```
notes/{uuid}/
  note    ← SSNT magic + version + metadata + encryptedPayload (no wrappedFEK)
  fek     ← raw wrappedFEK bytes (no length prefix)
```

**Rationale:** Option C from exploration; atomic operations at directory level; clear ownership per note.

**Alternatives considered:**
- Single combined `.note` file — rejected; cannot access FEK without reading payload
- Flat `notes/{uuid}.note` + `notes/{uuid}.fek` — rejected; user chose per-note directories

### 4. Wire format unchanged at repository boundary

ViewModels continue calling `writeNote(noteID:data:)` with full `.note` blob and `readNote` expecting full blob. `LocalNoteRepository` splits on write and reassembles on read internally.

**Rationale:** No ViewModel or protocol changes; backend upload later uses same blob.

### 5. Local note body format in SecureCrypto

New helpers (names TBD in implementation):

- `assembleLocalNoteBody(metadata:encryptedPayload:) -> Data`
- `parseLocalNoteBody(_:) -> (metadata: NoteMetadata, encryptedPayload: Data)`
- `splitNoteFile(_ wireBlob:) -> (metadata, wrappedFEK, encryptedPayload)` — convenience wrapping `parseNoteFile`
- `assembleNoteFile` — existing, used on read path

Local `note` file uses same `SSNT` magic and version byte as wire format, but omits the wrapped FEK section.

**Rationale:** Reuse metadata serialization; distinguish from wire blob by structure (two sections vs three).

### 6. Atomic writes

For create/update:

1. Write `note` and `fek` to `notes/{uuid}.tmp/`
2. Rename `notes/{uuid}.tmp/` → `notes/{uuid}/` (replace existing on update)

For delete: `removeItem` on `notes/{uuid}/`.

**Rationale:** Avoid orphan `note` without `fek` on crash mid-write.

### 7. Implementation in packages, not app Stub/

- `LocalNoteRepository` → `Packages/NoteRepository/Sources/NoteRepository/`
- `LocalVaultRepository` → `Packages/VaultRepository/Sources/VaultRepository/`
- Delete `FileNoteRepository.swift`, `FileVaultRepository.swift` from app target

`LocalNoteRepository` depends on `SecureCrypto` for split/reassemble and local body parse.

**Rationale:** Prod-like storage; testable in package; not DEBUG-gated.

### 8. AppDependencies wiring

```swift
noteRepository = LocalNoteRepository()
vaultRepository = LocalVaultRepository()

#if DEBUG
if StubBackendConfiguration.isEnabled {
    authRepository = InMemoryAuthRepository()
} else {
    authRepository = NetworkAuthRepository(...)
}
#else
authRepository = NetworkAuthRepository(...)
#endif
```

**Rationale:** Notes and vault always local until composite sync exists; stub flag is auth-only.

### 9. Error: corruptNote

Add `NoteRepositoryError.corruptNote` when note directory exists but only one of `note` / `fek` is present, or files are unreadable.

**Rationale:** Distinguishes incomplete storage from missing note (`noteNotFound`).

### 10. Validation on write

`writeNote` SHALL parse wire blob, verify `metadata.noteID == noteID` path parameter, then split and write.

**Rationale:** Matches `add-note-repository` design intent; prevents ID mismatch.

### 11. No migration

Old `stub-notes/*.note` and `stub-vault/` paths are abandoned. No dual-read. Developers delete app data or reinstall.

**Rationale:** User confirmed wipe and fresh.

## Risks / Trade-offs

- **[Orphan temp directories after crash]** → Acceptable; optional future cleanup scans `.tmp` dirs
- **[LocalNoteRepository depends on SecureCrypto]** → Breaks "opaque bytes only" ideal for network repo; acceptable for local impl only; network repo unchanged
- **[listNotes scans all note directories]** → Fine for v1; index cache deferred
- **[Network auth with local storage]** → Login may fail without backend in non-stub DEBUG; stub auth still available via `-UseStubBackend`
- **[No backup]** → User data lost if app deleted; acceptable per decision; export is future work

## Migration Plan

1. Implement SecureCrypto local body helpers + tests
2. Implement `LocalVaultRepository` + tests
3. Implement `LocalNoteRepository` + tests
4. Update `AppDependencies`; remove app stub repos
5. Update/remove affected app composition tests
6. Manual verification: register → create note → kill app → login → notes persist; verify no iCloud backup flag

No rollback of on-disk format needed — fresh install path only.

## Open Questions

None — all decisions confirmed during exploration.
