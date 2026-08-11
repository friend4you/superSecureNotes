## 1. AuthorizedRequestPerformer Core

- [ ] 1.1 Write failing tests: successful request returns data without refresh; `401` triggers `refreshSession`, `saveRefreshToken`, single retry with new Bearer token; second `401` after refresh throws `notAuthenticated`; refresh `401` propagates without retry; no session skips refresh (`AuthRepositoryTests/AuthorizedRequestPerformerTests.swift` — scenarios: Successful request without refresh, 401 triggers refresh and retry, Second 401 after successful refresh surfaces error, Refresh failure on 401 is terminal, No refresh when no in-memory session, Network error during refresh does not wipe session)
- [ ] 1.2 Implement `AuthorizedRequestPerformer` actor in `AuthRepository` target; make tests pass

## 2. Refresh Coalescing

- [ ] 2.1 Write failing tests: two concurrent `refreshSession()` calls issue one `POST /auth/refresh` and both receive updated session (`AuthRepositoryTests/NetworkAuthRepositoryRefreshCoalescingTests.swift` — scenario: Parallel refresh callers share one network call)
- [ ] 2.2 Add in-flight refresh task coalescing to `NetworkAuthRepository`; make tests pass

## 3. Refresh Token Persistence

- [ ] 3.1 Write failing tests: `AuthorizedRequestPerformer` calls `saveRefreshToken` after successful mid-session refresh (`AuthRepositoryTests/AuthorizedRequestPerformerPersistenceTests.swift` — scenario: Mid-session refresh persists rotated token)
- [ ] 3.2 Wire `CredentialStore` into performer; make tests pass
- [ ] 3.3 Write failing tests: `AuthSessionRestoreHelper.restoreSession` persists new refresh token to `CredentialStore` (`AuthFlowProtocolTests/AuthSessionRestorePersistenceTests.swift` — scenario: Unlock restore persists rotated token)
- [ ] 3.4 Update `AuthSessionRestoreHelper` or unlock flow to call `saveRefreshToken` after successful restore; make tests pass

## 4. NoteAPIClient Integration

- [ ] 4.1 Write failing tests: `NoteAPIClient.listNotes` retries after `401` + successful refresh; maps `notAuthenticated` when refresh fails (`NoteRepositoryTests/NoteAPIClientUnauthorizedRetryTests.swift` — scenarios: List notes retries after token refresh, List notes maps unauthorized after failed refresh)
- [ ] 4.2 Refactor `NoteAPIClient` to use `AuthorizedRequestPerformer`; remove per-method `accessToken` parameter where performer resolves token; make tests pass
- [ ] 4.3 Write failing tests: write body and delete note retry paths (`NoteRepositoryTests/NoteAPIClientUnauthorizedRetryTests.swift` — scenarios: Write body retries after token refresh, Delete note retries after token refresh)
- [ ] 4.4 Update remaining `NoteAPIClient` authenticated endpoints; make tests pass
- [ ] 4.5 Update `NetworkNoteRepository` to match new `NoteAPIClient` API; fix existing `NoteAPIClient*Tests` that pass `accessToken` explicitly

## 5. VaultAPIClient Integration

- [ ] 5.1 Write failing tests: `VaultAPIClient.readHeader` retries after `401` + successful refresh; maps `notAuthenticated` when refresh fails (`VaultRepositoryTests/VaultAPIClientUnauthorizedRetryTests.swift` — scenarios: Read header retries after token refresh, Vault maps unauthorized after failed refresh)
- [ ] 5.2 Refactor `VaultAPIClient` to use `AuthorizedRequestPerformer`; make tests pass
- [ ] 5.3 Write failing tests: write header and fetch public key retry paths (`VaultRepositoryTests/VaultAPIClientUnauthorizedRetryTests.swift` — scenarios: Write header retries after token refresh, Fetch public key retries after token refresh)
- [ ] 5.4 Update remaining `VaultAPIClient` authenticated endpoints; make tests pass

## 6. App Wiring and Forced Logout

- [ ] 6.1 Write failing tests: session-expired callback invokes `LogoutReset.perform` (Keychain wipe, vault clear) when performer signals dead refresh (`superSecureNotesTests/SessionExpiredLogoutTests.swift` — scenarios: Dead refresh token triggers full reset, Forced logout wipes Keychain)
- [ ] 6.2 Wire `AuthorizedRequestPerformer` in `AppDependencies` with `CredentialStore` and `onSessionExpired` → `LogoutReset.perform`; make tests pass
- [ ] 6.3 Write failing tests: unlock refresh failure followed by password re-login does not wipe Keychain (`AuthFlowProtocolTests/DefaultUnlockViewModelRefreshTests.swift` — scenario: Unlock refresh failure does not trigger forced logout)
- [ ] 6.4 Verify unlock flow unchanged for password re-login fallback; make tests pass

## 7. Session Expired Message

- [ ] 7.1 Write failing tests: forced logout sets session-expired message visible on login screen; user logout and unlock re-login do not (`NotesFlowTests/SessionExpiredMessageTests.swift` — scenarios: Message shown on session expiry logout, User-initiated logout has no session-expired message, Unlock password re-login has no session-expired message)
- [ ] 7.2 Add localized string and surface message in auth/login UI after forced logout; make tests pass

## 8. Integration Verification

- [ ] 8.1 Write failing integration test: expired access token during note sync recovers via refresh without user interaction (`superSecureNotesTests/SessionRefreshIntegrationTests.swift` — scenario: 401 triggers refresh and retry)
- [ ] 8.2 Wire end-to-end and make integration test pass
- [ ] 8.3 Manual: revoke refresh token server-side while app unlocked → forced logout with session-expired message; lock/unlock with valid refresh token → no message
