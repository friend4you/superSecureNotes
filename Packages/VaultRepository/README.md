# VaultRepository

Swift package providing server-backed vault header storage and user public-key lookup for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── VaultRepositoryProtocol   ← vault auth, sharing, feature modules
    └── VaultRepository           ← composition root / network implementation

VaultRepository
    └── VaultRepositoryProtocol

VaultRepositoryProtocol
    └── Foundation only
```

### Source folders

```
Sources/VaultRepositoryProtocol/
├── VaultRepository.swift          VaultRepository protocol
├── AccessTokenProviding.swift     Bearer token injection
└── VaultRepositoryError.swift

Sources/VaultRepository/
├── VaultRepository.swift          re-export entry point
├── NetworkVaultRepository.swift   actor implementation
└── Internal/                      VaultAPIClient, JSON DTOs (not public)

Tests/ mirror the same folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| Vault auth orchestration (future) | `VaultRepositoryProtocol` | Protocol and models only |
| Sharing module (future) | `VaultRepositoryProtocol` | Fetch recipient public keys |
| App composition root | `VaultRepository` | Wire `NetworkVaultRepository` at startup |
| Tests / mocks | `VaultRepositoryProtocol` | Mock `VaultRepository` without networking |

`VaultRepository` re-exports `VaultRepositoryProtocol` via `@_exported import`.

## Responsibilities

**VaultRepository owns:**

- Upload/download `vault.meta` bytes for the authenticated user
- Lookup another user's identity public key by `User.id` (UUID string)
- Bearer token auth via injected `AccessTokenProviding`
- Mapping HTTP errors to `VaultRepositoryError`

**VaultRepository does not:**

- Parse or validate `VaultHeader` (callers use `SecureCrypto`)
- Vault unlock, password flows, or `VaultSession` integration
- Note file sync or sharing orchestration
- Local file storage
- Separate `publishPublicKey` endpoint (public key indexed from uploaded header on server)

## v1 REST API contract

Base URL is configured at `NetworkVaultRepository` init (e.g. `https://api.example.com/v1`).

All endpoints require `Authorization: Bearer <accessToken>`.

| Method | Path | Success | Body |
|--------|------|---------|------|
| GET | `/vault/header` | 200 | Raw binary `vault.meta` |
| PUT | `/vault/header` | 204 | Raw binary `vault.meta` (`application/octet-stream`) |
| GET | `/users/{userId}/public-key` | 200 | `{ "publicKey": "<base64>", "algorithmId": 1 }` |

Error responses:

```json
{ "error": "header_not_found", "message": "..." }
```

Known error codes: `unauthorized`, `header_not_found`, `public_key_not_found`, `validation_error`.

## Products

- **VaultRepositoryProtocol** — `VaultRepository` protocol, `AccessTokenProviding`, `VaultRepositoryError`
- **VaultRepository** — `actor NetworkVaultRepository` default implementation

## Testing

```bash
cd Packages/VaultRepository && swift test
```

Network tests use `URLProtocol` stubs — no live backend required.
