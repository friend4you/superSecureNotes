## Context

`SecureCrypto` handles stateless vault crypto: create/unlock, `VaultHeader` serialize/parse, identity key pair in `vault.meta` v2. `VaultSession` holds UDK and identity private key in memory after unlock. `AuthRepository` provides server account auth (JWT) but has no vault or key-directory endpoints.

The `add-vault-session` design explicitly defers `vault.meta` persistence to an auth/storage layer. Multi-device sync and note sharing (FEK encryption for a recipient's public key) require:

1. Uploading/downloading the authenticated user's `vault.meta` blob to a backend
2. Looking up another user's identity public key by `User.id` (UUID string from auth)

No backend exists yet. This change defines the Swift repository and REST API contract — same pattern as `add-auth-flow-repository`.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/VaultRepository/` with `VaultRepositoryProtocol` and `VaultRepository` targets
- `VaultRepository` protocol: `readHeader()`, `writeHeader(_:)`, `fetchPublicKey(userID:)`
- `AccessTokenProviding` protocol for injected bearer-token auth
- `VaultRepositoryError` typed errors
- `NetworkVaultRepository` actor with internal `URLSession` HTTP client
- Repository boundary uses raw `Data` for headers; callers parse via `SecureCrypto`
- One vault per authenticated account (no vault ID in API paths)
- Server indexes `identity_public_key` from uploaded v2 headers for public-key directory
- Proposed v1 REST API for backend development
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Local file storage or offline fallback
- Note file sync (`<uuid>.note` blobs)
- Vault unlock orchestration, password flows, or `VaultSession` integration
- `SecureCrypto` changes
- Sharing UX, FEK encryption, or recipient validation logic in the repository
- Separate `publishPublicKey` endpoint (public key published implicitly via `writeHeader`)
- `hasHeader` convenience method (use `readHeader` + `headerNotFound`)
- Keychain token persistence
- Conflict resolution / ETags on header upload (last-write-wins in v1)
- SwiftUI screens

## Decisions

### 1. Package name: `VaultRepository`

```
Packages/VaultRepository/
├── Package.swift
├── Sources/
│   ├── VaultRepositoryProtocol/
│   │   ├── VaultRepository.swift
│   │   ├── AccessTokenProviding.swift
│   │   └── VaultRepositoryError.swift
│   └── VaultRepository/
│       ├── NetworkVaultRepository.swift
│       └── Internal/
│           ├── VaultAPIClient.swift
│           └── VaultResponseDTO.swift
└── Tests/
    ├── VaultRepositoryProtocolTests/
    └── VaultRepositoryTests/
```

**Rationale:** Mirrors `AuthFlow` / `AuthRepository` naming. User chose `VaultRepository` as the package name.

**Alternatives considered:**
- `VaultFlow` umbrella — rejected; user specified `VaultRepository`
- Single target — rejected; protocol/impl split matches project convention

### 2. Protocol module has zero networking dependencies

`VaultRepositoryProtocol` imports Foundation only. All HTTP, JSON DTOs, and `URLSession` live in `VaultRepository`.

**Rationale:** Feature code depends on contracts only. Network details are swappable.

### 3. `actor NetworkVaultRepository` as default implementation

```swift
public protocol AccessTokenProviding: Sendable {
    func accessToken() async throws -> String
}

public protocol VaultRepository: Sendable {
    func readHeader() async throws -> Data
    func writeHeader(_ header: Data) async throws
    func fetchPublicKey(userID: String) async throws -> Data
}
```

`NetworkVaultRepository` init: `baseURL: URL`, `tokenProvider: any AccessTokenProviding`, `session: URLSession = .shared`.

**Rationale:** Actor serializes concurrent requests. Token provider decouples from `AuthRepository` — app composition root wires `AuthRepository` conformance or a thin adapter.

**Alternatives considered:**
- Depend on `AuthRepositoryProtocol` directly — rejected; creates package coupling
- Pass token into each method — rejected; noisy call sites

### 4. Raw `Data` for header I/O

Repository returns/stores opaque `vault.meta` bytes. No `VaultHeader` type in protocol module.

**Rationale:** `VaultHeader` lives in `SecureCrypto`. Keeps `VaultRepositoryProtocol` free of crypto dependencies. Parse/serialize happens in future vault auth orchestration.

### 5. One vault per account

API paths are scoped to the authenticated user. No `vaultId` parameter.

**Rationale:** Current product model is one vault per account. Multi-vault can add path segments later.

### 6. Public key from vault header (implicit publish)

The identity public key is stored plaintext in `vault.meta` v2 (`identity_public_key`, 32 bytes). On `PUT /vault/header`, the server:

1. Stores the full header blob privately for the authenticated user
2. Parses enough of the blob to extract `identity_public_key` and indexes it by `userId`

`GET /users/{userId}/public-key` returns only the indexed public key — never the full header.

**Rationale:** Single upload publishes both wrapped keys and directory entry. No separate publish call. Matches `add-vault-identity-keys` design.

**Alternatives considered:**
- Separate `POST /users/me/public-key` — rejected; duplicates data already in header

### 7. Onboarding and multi-device flows

```
New user:
  register/login (AuthRepository)
  → create vault locally (SecureCrypto)
  → writeHeader(headerBytes)

New device:
  login (AuthRepository)
  → readHeader() — 404 means route to "create vault"
  → unlock (SecureCrypto) → VaultSession.establish()

Sharing (future module):
  fetchPublicKey(recipientUserID) → encrypt FEK
  — 404 handled by sharing layer, not repository
```

### 8. Client-side validation

- `writeHeader`: reject empty `Data` locally with `validationError`
- `fetchPublicKey`: reject empty `userID` locally with `validationError`

**Rationale:** Fail fast; mirrors `AuthRepository` credential validation.

### 9. Proposed v1 REST API contract

Base URL: configurable at `NetworkVaultRepository` init (e.g. `https://api.supersecurenotes.example/v1`).

All vault endpoints require `Authorization: Bearer <accessToken>` from `AccessTokenProviding`.

#### GET `/vault/header`

Response `200 OK`:
- Body: raw binary `vault.meta` (`Content-Type: application/octet-stream`)

Errors:
- `401` — missing or invalid token → `VaultRepositoryError.notAuthenticated`
- `404` — no vault uploaded yet → `VaultRepositoryError.headerNotFound`

#### PUT `/vault/header`

Request:
- Body: raw binary `vault.meta` (`Content-Type: application/octet-stream`)

Response `204 No Content` on success.

Server side-effect: extract and index `identity_public_key` from v2 header (if present).

Errors:
- `401` — `notAuthenticated`
- `400` — invalid header blob → `VaultRepositoryError.validationError`

#### GET `/users/{userId}/public-key`

Path parameter `userId`: UUID string matching `User.id` from auth.

Response `200 OK`:
```json
{
  "publicKey": "<base64-encoded 32 bytes>",
  "algorithmId": 1
}
```

`algorithmId` `1` = Curve25519 (X25519), matching `vault.meta` v2 `identity_algorithm_id`.

Errors:
- `401` — `notAuthenticated`
- `404` — user not found or no public key indexed → `VaultRepositoryError.publicKeyNotFound`

#### Error response body (all error statuses)

```json
{
  "error": "header_not_found",
  "message": "No vault header exists for this account."
}
```

Known `error` codes for v1:

| Code | HTTP | Maps to |
|------|------|---------|
| `unauthorized` | 401 | `VaultRepositoryError.notAuthenticated` |
| `header_not_found` | 404 | `VaultRepositoryError.headerNotFound` |
| `public_key_not_found` | 404 | `VaultRepositoryError.publicKeyNotFound` |
| `validation_error` | 400 | `VaultRepositoryError.validationError` |
| (other / network) | any | `VaultRepositoryError.networkError` or `.serverError` |

### 10. VaultRepositoryError

```swift
public enum VaultRepositoryError: Error, Equatable, Sendable {
    case notAuthenticated
    case headerNotFound
    case publicKeyNotFound
    case validationError(String)
    case networkError
    case serverError(statusCode: Int)
}
```

### 11. Internal HTTP client (not a public protocol)

`VaultAPIClient` is `internal` to `VaultRepository` target. Injectable `URLSession` for tests via internal init.

**Rationale:** Matches `AuthRepository` pattern. Tests use `URLProtocol` stubs.

### 12. Products and import guidance

| Consumer | Import |
|----------|--------|
| Vault auth orchestration (future) | `VaultRepositoryProtocol` |
| Sharing module (future) | `VaultRepositoryProtocol` |
| App composition root | `VaultRepository` + `VaultRepositoryProtocol` |
| Tests / mocks | `VaultRepositoryProtocol` |

`VaultRepository` target `@_exported import VaultRepositoryProtocol` at module entry (mirror `AuthRepository` pattern).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| No backend yet — integration untested against real server | Define API contract in design; use `URLProtocol` stub tests; backend follows same contract |
| Last-write-wins on header upload — multi-device race | Documented v1 limitation; ETag/conflict detection deferred |
| Server must parse binary `vault.meta` to index public key | Document field offsets in backend contract; v2 format is stable in `add-vault-identity-keys` |
| v1 header upload has no identity fields | Server cannot index public key; `fetchPublicKey` returns 404 until v2 header uploaded |
| Recipient without vault returns 404 on `fetchPublicKey` | Repository throws `publicKeyNotFound`; sharing layer owns UX |
| Token expiry during vault operation | Caller refreshes session via `AuthRepository` before vault calls; auto-refresh deferred |

## Migration Plan

Greenfield addition — no migration.

1. Add `Packages/VaultRepository` with TDD
2. Link products in Xcode project (no runtime wiring until vault auth exists)
3. Build backend implementing REST contract from this design
4. Future: vault auth module wires `readHeader` / `writeHeader` with `SecureCrypto` and `VaultSession`

Rollback: remove package reference from Xcode; delete `Packages/VaultRepository/`.

## Open Questions

None — exploration decisions captured above.
