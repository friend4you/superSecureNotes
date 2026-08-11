## Why

Access tokens expire during normal app use (note sync, vault operations, sharing). Today every API client maps `401 unauthorized` to `notAuthenticated` and stops — there is no automatic refresh and retry. The original auth design explicitly deferred this ("auto-refresh middleware deferred"). Users should stay signed in while unlocked without re-entering credentials until the refresh token itself is dead.

## What Changes

- Add shared **authorized HTTP performer** — on `401 unauthorized`, call `refreshSession()` once, persist rotated refresh token to `CredentialStore`, retry the original request once
- Wire performer into `NoteAPIClient` and `VaultAPIClient` (all authenticated endpoints)
- Persist new refresh token after every successful refresh (mid-session and on unlock restore)
- On refresh failure mid-session (`401` on `/auth/refresh`): full `LogoutReset` wipe + user-visible "session expired" message
- On refresh failure during unlock: keep existing password re-login fallback (no wipe)
- No proactive/preemptive refresh — only react to `401` from the server
- Lock behavior unchanged (memory clear only); logout behavior unchanged (full wipe)

## Capabilities

### New Capabilities

- `auto-token-refresh`: Shared 401 → refresh → retry orchestration, refresh-token persistence on success, forced logout on dead refresh mid-session

### Modified Capabilities

- `note-repository`: Network API clients attempt token refresh and single retry before surfacing `notAuthenticated`
- `notes-flow`: Surface session-expired message when forced logout is triggered by dead refresh token
- `session-lock`: Forced logout on expired refresh token mid-session uses same full reset as user logout

## Impact

- `Packages/AuthFlow/Sources/AuthRepository/` — new `AuthorizedRequestPerformer` (or equivalent), refresh coalescing in `NetworkAuthRepository`, `CredentialStore` integration for token rotation
- `Packages/NoteRepository/Sources/NoteRepository/Internal/NoteAPIClient.swift` — route HTTP through performer
- `Packages/VaultRepository/Sources/VaultRepository/Internal/VaultAPIClient.swift` — route HTTP through performer
- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — persist refresh token on unlock restore; session-expired notification hook
- `superSecureNotes/AppDependencies.swift` — wire performer, credential store, and logout callback
- `Packages/NotesFlow/` — display session-expired message before redirect to login
- Out of scope: proactive `expiresAt` refresh, server API changes, refresh while locked (no in-memory session)
