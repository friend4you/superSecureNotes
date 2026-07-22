## Context

`SecureCrypto` and `VaultSession` handle local vault encryption and in-memory key lifecycle. `NotesFlow` provides note UI placeholders. No server account layer exists — there is no networking code, no auth repository, and no backend API.

This change introduces the **account auth** layer: a repository that talks to a remote API for email/password registration and login. It is intentionally separate from local vault unlock (`SecureCrypto` / `VaultSession`). A future `AuthFlow` UI package will consume `AuthRepositoryProtocol`; this change delivers only the repository contract and network implementation.

No backend exists yet. The REST API defined here is the **shared contract** for both the Swift client and the backend to be built next.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/AuthFlow/` with `AuthRepositoryProtocol` and `AuthRepository` targets
- `AuthRepository` protocol: `register`, `login`, `logout`, `refreshSession`, `currentSession`, `currentUser`
- Shared models: `LoginCredentials`, `RegisterCredentials`, `User`, `AuthSession`, `AuthRepositoryError`
- `NetworkAuthRepository` actor with internal `URLSession` HTTP (not exposed as public protocol)
- JWT access + refresh token model in `AuthSession`
- In-memory session storage only
- Proposed v1 REST API for backend development
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- SwiftUI login/register screens (`AuthFlow` UI — future change)
- Keychain or persistent token storage
- Biometrics, OAuth, social login
- Integration with `VaultSession` or `SecureCrypto`
- Email verification, password reset, account deletion (future API versions)
- Public `HTTPClient` protocol (networking fully internal to `AuthRepository` target)

## Decisions

### 1. Package name: `AuthFlow`

```
Packages/AuthFlow/
├── Package.swift
├── Sources/
│   ├── AuthRepositoryProtocol/
│   │   ├── AuthRepository.swift
│   │   ├── Models/
│   │   │   ├── LoginCredentials.swift
│   │   │   ├── RegisterCredentials.swift
│   │   │   ├── User.swift
│   │   │   └── AuthSession.swift
│   │   └── AuthRepositoryError.swift
│   └── AuthRepository/
│       ├── NetworkAuthRepository.swift
│       └── Internal/
│           ├── AuthAPIClient.swift      # internal URLSession wrapper
│           └── AuthResponseDTO.swift    # internal JSON mapping
└── Tests/
    ├── AuthRepositoryProtocolTests/
    └── AuthRepositoryTests/
```

**Rationale:** `AuthFlow` is the umbrella package for all auth-domain code. UI targets can be added later (`AuthFlowUI` or views inside the same package). Repository is the first slice.

**Alternatives considered:**
- Separate `AuthRepository` package — rejected; user wants `AuthFlow` umbrella
- Single target — rejected; protocol/impl split matches `VaultSession` convention

### 2. Protocol module has zero networking dependencies

`AuthRepositoryProtocol` imports Foundation only. All HTTP, JSON DTOs, and `URLSession` live in `AuthRepository`.

**Rationale:** Feature code and future UI depend on contracts only. Network details are swappable without changing the protocol module.

### 3. `actor NetworkAuthRepository` as default implementation

```swift
public protocol AuthRepository: Sendable {
    var currentSession: AuthSession? { get async }
    var currentUser: User? { get async }

    func register(_ credentials: RegisterCredentials) async throws -> AuthSession
    func login(_ credentials: LoginCredentials) async throws -> AuthSession
    func logout() async throws
    func refreshSession() async throws -> AuthSession
}
```

**Rationale:** Actor serializes in-memory session state across async tasks. Matches `VaultSession` actor pattern.

**Alternatives considered:**
- `class` + lock — more boilerplate; rejected
- Session observation stream — deferred; UI can poll `currentSession` or add `changes` in a follow-up

### 4. AuthSession model (JWT access + refresh)

```swift
public struct AuthSession: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
}
```

`expiresAt` computed client-side from server `expiresIn` (seconds) at login/register/refresh time.

**Rationale:** Standard JWT session shape. Refresh token enables silent re-auth without re-entering password (when persistence is added later).

### 5. User model

```swift
public struct User: Sendable, Equatable, Codable {
    public let id: String       // UUID string from server
    public let email: String
    public let createdAt: Date
}
```

**Rationale:** Minimal v1 profile. Backend can extend with display name later without breaking the protocol if fields are additive in API responses (DTO ignores unknown keys).

### 6. In-memory session only

`NetworkAuthRepository` holds `currentSession` and `currentUser` in actor state. App restart requires re-login.

**Rationale:** Explicit v1 scope. Keychain persistence is a future change behind the same `AuthRepository` protocol.

### 7. Internal HTTP client (not a public protocol)

`AuthAPIClient` is `internal` to `AuthRepository` target. Uses `URLSession` with injectable `URLSession` in `init` for tests (package-internal or `internal init(session:baseURL:)`).

**Rationale:** User chose fully internal networking. Tests stub via custom `URLSession` with `URLProtocol` or inject session at package-internal test seam.

### 8. Proposed v1 REST API contract

Base URL: configurable at `NetworkAuthRepository` init (e.g. `https://api.supersecurenotes.example/v1`).

All requests/responses: `Content-Type: application/json`.

#### POST `/auth/register`

Request:
```json
{
  "email": "user@example.com",
  "password": "secure-password"
}
```

Response `201 Created`:
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "createdAt": "2026-07-22T12:00:00Z"
  },
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "expiresIn": 3600
}
```

Errors:
- `400` — validation error (invalid email format, password too short)
- `409` — email already registered

#### POST `/auth/login`

Request:
```json
{
  "email": "user@example.com",
  "password": "secure-password"
}
```

Response `200 OK`: same shape as register response.

Errors:
- `401` — invalid credentials

#### POST `/auth/logout`

Headers: `Authorization: Bearer <accessToken>`

Response `204 No Content`

Errors:
- `401` — invalid or expired token

#### POST `/auth/refresh`

Request:
```json
{
  "refreshToken": "eyJ..."
}
```

Response `200 OK`:
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "expiresIn": 3600
}
```

Errors:
- `401` — invalid or expired refresh token

#### GET `/auth/me`

Headers: `Authorization: Bearer <accessToken>`

Response `200 OK`:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "createdAt": "2026-07-22T12:00:00Z"
}
```

Errors:
- `401` — invalid or expired token

#### Error response body (all error statuses)

```json
{
  "error": "invalid_credentials",
  "message": "Email or password is incorrect."
}
```

Known `error` codes for v1:

| Code | HTTP | Maps to |
|------|------|---------|
| `invalid_credentials` | 401 | `AuthRepositoryError.invalidCredentials` |
| `email_already_exists` | 409 | `AuthRepositoryError.emailAlreadyExists` |
| `validation_error` | 400 | `AuthRepositoryError.validationError` |
| `unauthorized` | 401 | `AuthRepositoryError.notAuthenticated` |
| (other / network) | any | `AuthRepositoryError.networkError` or `.serverError` |

### 9. AuthRepositoryError

```swift
public enum AuthRepositoryError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError(String)
    case notAuthenticated
    case networkError
    case serverError(statusCode: Int)
}
```

**Rationale:** Typed errors for UI mapping. No raw HTTP details leak beyond `serverError` status code.

### 10. Logout behavior

`logout()` calls `POST /auth/logout` with current access token, then clears in-memory session and user regardless of network outcome (best-effort server invalidation, always clear local state).

**Rationale:** User should always be logged out locally even if server is unreachable.

### 11. Products and import guidance

| Consumer | Import |
|----------|--------|
| AuthFlow UI (future) | `AuthRepositoryProtocol` |
| App composition root | `AuthRepository` + `AuthRepositoryProtocol` |
| Tests / mocks | `AuthRepositoryProtocol` |

`AuthRepository` target `@_exported import AuthRepositoryProtocol` at module entry (mirror `VaultSession` pattern).

### 12. Password validation (client-side, minimal)

Repository validates non-empty email and password before network call. Email format validation optional in v1 (server is authoritative).

**Rationale:** Fail fast on obvious bad input; map server `validation_error` for detailed messages.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| No backend yet — integration untested against real server | Define API contract in design; use `URLProtocol` stub tests; backend change follows same contract |
| In-memory session lost on app kill | Documented v1 limitation; Keychain persistence is future work |
| JWT expiry not auto-refreshed | Caller invokes `refreshSession()`; auto-refresh middleware deferred |
| `AuthRepository` name collides with OpenSpec "auth module" (vault unlock) | Document distinction: `AuthRepository` = server accounts; vault unlock = future `VaultAuth` |
| Internal HTTP client harder to mock than public protocol | Inject `URLSession` via internal init; `URLProtocol` stubs in tests |

## Migration Plan

Greenfield addition — no migration.

1. Add `Packages/AuthFlow` with TDD
2. Link products in Xcode project (no runtime wiring until UI exists)
3. Build backend implementing REST contract from this design
4. Future: AuthFlow UI + app router consuming `AuthRepository`

Rollback: remove package reference from Xcode; delete `Packages/AuthFlow/`.

## Open Questions

None — exploration decisions captured above.
