## Why

superSecureNotes needs to work fully offline before a backend exists. Today, note and vault persistence live in DEBUG-only app stubs (`FileNoteRepository`, `FileVaultRepository`) gated by `-UseStubBackend`, while Release builds point at a non-existent API. Users need production-like local storage for encrypted notes and vault headers, with wrapped FEKs stored separately from note payloads for future sharing and efficient key access.

## What Changes

- Add `LocalNoteRepository` in the `NoteRepository` package — persists notes under `Application Support/superSecureNotes/notes/{uuid}/` as split `note` + `fek` files
- Add `LocalVaultRepository` in the `VaultRepository` package — persists vault header under `Application Support/superSecureNotes/vault/vault-header.bin`
- Add SecureCrypto helpers for local on-disk note body format (metadata + encrypted payload, no FEK section) and split/reassemble with wire-format `.note` blobs
- Wire `AppDependencies` to use local repositories in all builds; restrict `-UseStubBackend` to auth only (`InMemoryAuthRepository`)
- Exclude vault and notes directories from iCloud backup
- Atomic directory-level writes (temp dir → rename) for note create/update
- Add `NoteRepositoryError.corruptNote` when note directory is incomplete
- **BREAKING**: Remove DEBUG-only `FileNoteRepository` and `FileVaultRepository` from app `Stub/`; no migration from old `stub-notes/` / `stub-vault/` layout (wipe and fresh)
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

<!-- No new top-level packages; behavior extends existing modules -->

### Modified Capabilities

- `note-repository`: `LocalNoteRepository` with split FEK storage, atomic writes, `corruptNote` error; prod local persistence in all builds
- `vault-repository`: `LocalVaultRepository` with Application Support path and iCloud backup exclusion
- `secure-crypto`: Local on-disk note body format and parse/assemble helpers (metadata + payload without FEK section)
- `app-navigation`: `AppDependencies` uses local note and vault repositories in all builds; stub flag controls auth only
- `debug-stub-backend`: Remove `FileNoteRepository` / `FileVaultRepository` stub requirements; stub mode no longer selects note or vault repositories

## Impact

- `Packages/NoteRepository/` — `LocalNoteRepository` actor, tests, optional `SecureCrypto` dependency for split/reassemble
- `Packages/VaultRepository/` — `LocalVaultRepository` actor, tests
- `Packages/SecureCrypto/` — local note body parse/assemble helpers, tests
- `superSecureNotes/AppDependencies.swift` — local repo wiring for all builds
- `superSecureNotes/Stub/` — remove `FileNoteRepository.swift`, `FileVaultRepository.swift`
- `superSecureNotesTests/` — replace stub repository tests with app composition tests for local wiring
- Out of scope: `NoteRepository` protocol changes, `readWrappedFEK` API, recipient FEK files, backend sync/composite repository, migration from old stub layout, Keychain session persistence, `NotesFlow` ViewModel changes
