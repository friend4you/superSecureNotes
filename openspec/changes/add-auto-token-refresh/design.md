## Context

`AuthRepository` already exposes `refreshSession()` and `POST /auth/refresh`. `CredentialStore` persists the refresh token in Keychain across lock/unlock. `LockCoordinator` clears in-memory auth on lock but leaves Keychain intact. `LogoutReset` wipes everything on user logout.

`NoteAPIClient` and `VaultAPIClient` each have internal `perform(_:expectedSuccessCodes:)` that maps `401` → `.notAuthenticated` with no retry. `NetworkAuthRepository` is an `actor`, which naturally serializes concurrent `refreshSession()` calls.

Prior changes deferred auto-refresh to a future slice. This change delivers 401-triggered refresh only — no preemptive expiry checks.

## Goals / Non-Goals

**Goals:**

- On `401 unauthorized` from any authenticated API call (notes, vault, sharing): refresh access token once, persist new refresh token, retry original request once
- Coalesce concurrent refreshes so parallel 401s trigger a single `/auth/refresh`
- Persist rotated refresh token to `CredentialStore` after every successful refresh (mid-session and unlock restore)
- Mid-session refresh failure (`401` on `/auth/refresh`): `LogoutReset.perform` full wipe + localized session-expired message
- Unlock refresh failure: keep password re-login fallback (no wipe)
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Proactive refresh based on `expiresAt` before requests
- Refresh while app is locked (no in-memory session; no network with stale token)
- Server API changes
- Refresh retry on `/auth/refresh` itself (401 there is terminal)
- Changing lock semantics (memory-only) or user-initiated logout semantics (full wipe)

## Decisions

### 1. Shared `AuthorizedRequestPerformer` in `AuthRepository` target

```swift
// AuthRepository target (internal or package-internal public)
actor AuthorizedRequestPerformer {
    func perform(
        _ request: URLRequest,
        expectedSuccessCodes: Set<Int>,
        mapError: (Int, Data) -> Error
    ) async throws -> Data
}
```

Flow:

```
Request + Bearer token
    │
    ├── 2xx → return data
    │
    └── 401 unauthorized
            │
            ▼
        refreshSession()  (actor-coalesced)
            │
            ├── 200 → saveRefreshToken → rebuild request with new token → retry ONCE
            │
            └── 401 → SessionRefreshFailed → caller triggers LogoutReset
```

**Rationale:** Single place for retry logic; avoids duplicating wrappers across `NetworkNoteRepository` (15+ call sites) and vault methods.

**Alternatives considered:**
- Repository-level retry wrapper — rejected; too many call sites, easy to miss new endpoints
- Enhanced `AccessTokenProviding` only — rejected; token provider cannot see HTTP status codes
- URLSession delegate interceptor — rejected; harder to test and retry with modified headers in Swift

### 2. Performer dependencies

| Dependency | Role |
|------------|------|
| `AuthRepository` | `refreshSession()`, `currentSession` |
| `CredentialStore` | `saveRefreshToken(_:)` after successful refresh |
| `URLSession` | HTTP transport (injected for tests) |
| `onRefreshFailed` callback | Optional; app wires to `LogoutReset` + message |

Performer reads access token from `authRepository.currentSession` before each attempt. On successful refresh, calls `credentialStore.saveRefreshToken(session.refreshToken)`.

**Rationale:** Keeps `CredentialStore` out of low-level API clients; rotation persistence is a cross-cutting auth concern.

### 3. NoteAPIClient token resolution unified with VaultAPIClient

`NoteAPIClient` currently receives `accessToken` as a per-method parameter from `NetworkNoteRepository`. Refactor to inject `AuthorizedRequestPerformer` (or `AccessTokenProviding` + performer) so `makeAuthorizedRequest` resolves the token internally — matching `VaultAPIClient` pattern.

**Rationale:** Retry must rebuild the request with a new token inside `perform`; passing token as a parameter forces every repository method to own retry logic.

### 4. Refresh coalescing via `NetworkAuthRepository` actor + in-flight task

```swift
// NetworkAuthRepository (actor)
private var refreshTask: Task<AuthSession, Error>?

func refreshSession() async throws -> AuthSession {
    if let refreshTask { return try await refreshTask.value }
    let task = Task { try await apiClient.refresh(...) }
    refreshTask = task
    defer { refreshTask = nil }
    ...
}
```

Concurrent 401s await the same in-flight refresh rather than issuing parallel `/auth/refresh` calls.

**Alternatives considered:**
- Separate `RefreshCoordinator` actor — rejected; `NetworkAuthRepository` is already an actor

### 5. Session refresh failure signaling

Define `SessionRefreshError.sessionExpired` (or reuse `AuthRepositoryError.notAuthenticated` with a dedicated callback). App composition wires:

```swift
onSessionExpired: {
    sessionExpiredMessage = localizedString
    await LogoutReset.perform(...)
}
```

Message shown once before navigation to login (banner, alert, or auth-flow state).

**Rationale:** User requested visible message on forced logout; distinguish from silent lock.

### 6. Unlock restore persists rotated refresh token

Update `AuthSessionRestoreHelper.restoreSession` (or `DefaultUnlockViewModel.restoreOnlineSession`) to call `credentialStore.saveRefreshToken` after successful restore — same as mid-session refresh.

On restore failure: existing `retryLoginAfterRestoreFailure` path unchanged (password re-login, no wipe).

### 7. No refresh while locked

`LockCoordinator` calls `authRepository.clearSession()`. Performer has no session → throws `notAuthenticated` immediately without calling `/auth/refresh`. Sync and network calls should not run while locked (existing lifecycle).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 401 caused by something other than expired access token (e.g. revoked account) | Single refresh + retry; second 401 surfaces error; refresh 401 triggers logout |
| Thundering herd on concurrent 401s | Actor-coalesced `refreshSession` with shared in-flight task |
| Stale Keychain refresh token after rotation if persistence skipped | Persist on every successful refresh (mid-session + unlock) |
| Retry replays non-idempotent request (e.g. PUT) | Acceptable v1; server should be idempotent on PUT; only one retry |
| Network error during refresh | Do not logout; propagate `networkError` (cannot know if token is dead) |
| Forced logout during active note edit | User loses unsaved local state; same as manual logout; message explains why |

## Migration Plan

Greenfield behavior change inside existing packages:

1. Add `AuthorizedRequestPerformer` with TDD (`URLProtocol` stubs)
2. Refactor `NoteAPIClient` and `VaultAPIClient` to use performer
3. Wire in `AppDependencies` with `CredentialStore` + logout callback
4. Add unlock restore persistence
5. Add session-expired message in `NotesFlow` / app layer
6. Manual: let access token expire → background sync recovers without re-login; revoke refresh token → forced logout with message

Rollback: revert performer wiring; API clients return to immediate `401` mapping.

## Open Questions

None — resolved in exploration:

- Unlock failure → password re-login (not wipe)
- Mid-session refresh failure → full logout with message
- 401-only refresh (no proactive)
- Persist refresh token on unlock restore
