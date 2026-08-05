## Why

`LocalFirstNoteSyncService` already implements vault header upload and empty-local catalog pull, but auth view models never call these paths. Register schedules a fire-and-forget `PUT /vault/header` (errors swallowed), so the backend may have no vault after a “successful” register. Login reads only the local vault file, so a fresh install or wiped device cannot restore an existing account even when the server has the vault and notes.

## What Changes

- **Register:** After creating and writing the vault header locally, **await** `PUT /v1/vault/header`. If upload fails, register **fails** (no `hasLocalSetup`, no navigation to notes). Attempt auth session cleanup when register succeeded but vault upload failed.
- **Login (empty local):** After auth succeeds, when local vault header is missing, pull vault header from `GET /v1/vault/header`, unlock with password, open notes index, then pull owned notes into local storage as `.synced`.
- **Sync API split:** Separate vault-header pull from note-catalog pull so header fetch happens before unlock and note import happens after index open (fixes ordering bug in monolithic `pullCatalogIfLocalVaultMissing`).
- **Login wiring:** Inject `NoteSyncing` into `DefaultLoginViewModel` (unlock already has it).
- **Supersedes** the fire-and-forget register vault upload requirement from `add-local-first-sync` (implementation existed; auth hook for login pull was never completed — task 9.3).

## Capabilities

### New Capabilities

- `vault-sync-on-auth`: Register fail-fast vault upload; login empty-local vault + notes pull; split sync orchestrator pull API

### Modified Capabilities

- `local-first-sync`: Register vault upload changes from fire-and-forget to blocking/fail-fast; empty-local pull requirement clarified with explicit auth wiring and pull ordering

## Impact

- `Packages/NoteRepository/` — split pull API on `LocalFirstNoteSyncService`; optional `uploadVaultHeader` await variant
- `Packages/NoteRepositoryProtocol/` — extend `NoteCatalogPulling` / `VaultHeaderUploadScheduling` if needed
- `Packages/AuthFlow/` — `DefaultRegisterViewModel`, `DefaultLoginViewModel`, `AuthFlowDependencies`
- `superSecureNotes/AppComposition.swift` — ensure login receives same `noteSyncService` as register/unlock
- Tests in `AuthFlowProtocolTests`, `NoteRepositoryTests`, optional app integration test
- Depends on `super-secure-notes-api` at `http://localhost:8000/v1`
