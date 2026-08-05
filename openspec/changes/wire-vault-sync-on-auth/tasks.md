## 1. Sync orchestrator — split pull API

- [ ] 1.1 Write failing tests: `pullVaultHeaderIfLocalMissing()` fetches/writes header when local missing, returns nil when local exists; `pullRemoteNotesCatalog()` imports notes when index open (`LocalFirstNoteSyncServiceTests`)
- [ ] 1.2 Add `pullVaultHeaderIfLocalMissing()` and `pullRemoteNotesCatalog()` to protocol + `LocalFirstNoteSyncService`; refactor or update `pullCatalogIfLocalVaultMissing()`; make tests pass

## 2. Sync orchestrator — await vault upload

- [ ] 2.1 Write failing tests: `uploadVaultHeaderOrThrow` (or await upload) succeeds on `204`, throws on network/server error (`LocalFirstNoteSyncServiceTests`)
- [ ] 2.2 Implement throwing vault header upload for register path; keep `scheduleVaultHeaderUpload` for non-blocking callers if still needed; make tests pass

## 3. Register — fail-fast vault upload

- [ ] 3.1 Write failing tests: register succeeds only when vault PUT succeeds; register fails and clears session when PUT fails (`DefaultRegisterViewModelSuccessTests`, `DefaultRegisterViewModelErrorTests`)
- [ ] 3.2 Update `DefaultRegisterViewModel` to await vault upload before unlock/saveSetup; attempt auth session cleanup on upload failure; make tests pass

## 4. Login — empty-local pull

- [ ] 4.1 Write failing tests: login pulls vault header when local missing, unlocks, pulls notes after index open; login reads local header when file exists; maps remote 404 to vault not found (`DefaultLoginViewModelSuccessTests`, `DefaultLoginViewModelErrorTests`)
- [ ] 4.2 Inject `noteSync` into `DefaultLoginViewModel` via `AuthFlowDependencies`; implement pull → unlock → open → pull notes sequence; make tests pass

## 5. App composition

- [ ] 5.1 Write failing test: `AppComposition` passes same `noteSyncService` to login/register/unlock auth dependencies (`AppCompositionTests`)
- [ ] 5.2 Verify wiring in `AppComposition` / `AuthFlowDependencies`; make test pass

## 6. Manual verification

- [ ] 6.1 With API on `:8000`: register new user → confirm `GET /v1/vault/header` returns header
- [ ] 6.2 Delete app / clear local data → login same account → vault unlocks and notes appear without manual refresh
- [ ] 6.3 Simulate failed vault PUT during register (e.g. stop API mid-flow) → register fails, user not marked setup
