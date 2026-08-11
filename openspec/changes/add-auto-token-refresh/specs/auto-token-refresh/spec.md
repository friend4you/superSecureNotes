## ADDED Requirements

### Requirement: AuthorizedRequestPerformer

The `AuthRepository` target SHALL provide an `AuthorizedRequestPerformer` actor that executes authenticated HTTP requests. It SHALL attach `Authorization: Bearer <accessToken>` from `AuthRepository.currentSession`. When the server responds `401` with error code `unauthorized`, it SHALL call `AuthRepository.refreshSession()` once, persist the new refresh token via `CredentialStore.saveRefreshToken(_:)`, rebuild the request with the new access token, and retry the original request exactly once. It SHALL NOT refresh preemptively based on `expiresAt`.

#### Scenario: Successful request without refresh

- **WHEN** an authenticated request receives a success status code
- **THEN** the response body is returned and no refresh call is made

#### Scenario: 401 triggers refresh and retry

- **WHEN** an authenticated request receives `401` with error code `unauthorized` and `refreshSession()` succeeds
- **THEN** `saveRefreshToken` is called with the new refresh token, the original request is retried once with the new access token, and the retry response is returned

#### Scenario: Second 401 after successful refresh surfaces error

- **WHEN** a request receives `401`, refresh succeeds, and the retried request also receives `401`
- **THEN** the performer throws the repository-specific `notAuthenticated` error without further refresh attempts

#### Scenario: Refresh failure on 401 is terminal

- **WHEN** an authenticated request receives `401` and `refreshSession()` throws `AuthRepositoryError.notAuthenticated`
- **THEN** the performer propagates session-expired failure without retrying the original request

#### Scenario: No refresh when no in-memory session

- **WHEN** `currentSession` is `nil` (e.g. app is locked)
- **THEN** the performer throws `notAuthenticated` without calling `/auth/refresh`

#### Scenario: Network error during refresh does not wipe session

- **WHEN** an authenticated request receives `401` and `refreshSession()` throws `AuthRepositoryError.networkError`
- **THEN** the performer propagates `networkError` and does not invoke session-expired logout

### Requirement: Concurrent refresh coalescing

`NetworkAuthRepository.refreshSession()` SHALL coalesce concurrent refresh calls so that parallel callers await a single in-flight `/auth/refresh` request.

#### Scenario: Parallel refresh callers share one network call

- **WHEN** two tasks call `refreshSession()` concurrently while a session exists
- **THEN** only one `POST /auth/refresh` request is sent and both callers receive the same updated `AuthSession`

### Requirement: Refresh token persistence on successful refresh

After every successful `refreshSession()` or `restoreSession(refreshToken:)` that returns a new `AuthSession`, the system SHALL call `CredentialStore.saveRefreshToken(_:)` with the returned `refreshToken`.

#### Scenario: Mid-session refresh persists rotated token

- **WHEN** `AuthorizedRequestPerformer` triggers a successful `refreshSession()` during an API call
- **THEN** `credentialStore.refreshToken()` returns the new refresh token string

#### Scenario: Unlock restore persists rotated token

- **WHEN** `AuthSessionRestoreHelper.restoreSession` succeeds during online unlock
- **THEN** `credentialStore.refreshToken()` returns the refresh token from the restored session

### Requirement: Mid-session refresh failure triggers forced logout

When `AuthorizedRequestPerformer` determines the refresh token is dead (`refreshSession()` returns `401 unauthorized`), the app SHALL invoke `LogoutReset.perform` (full Keychain wipe, local data wipe, vault clear) and SHALL NOT treat the event as a lock.

#### Scenario: Dead refresh token triggers full reset

- **WHEN** an API call receives `401`, refresh fails with `notAuthenticated`, and the app handles session expiry
- **THEN** `credentialStore.hasLocalSetup` is `false` and in-memory vault and auth state are cleared

#### Scenario: Unlock refresh failure does not trigger forced logout

- **WHEN** refresh fails during online unlock and password re-login succeeds
- **THEN** `credentialStore.hasLocalSetup` remains `true` and the user proceeds to vault unlock

### Requirement: Auth refresh endpoint excluded from auto-retry

`AuthAPIClient.refresh` SHALL NOT use `AuthorizedRequestPerformer`. A `401` on `/auth/refresh` SHALL map directly to `AuthRepositoryError.notAuthenticated`.

#### Scenario: Refresh endpoint maps 401 without retry loop

- **WHEN** `POST /auth/refresh` responds `401` with error code `unauthorized`
- **THEN** `refreshSession` throws `notAuthenticated` without attempting another refresh
