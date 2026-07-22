# AuthFlow

Swift package providing server account authentication for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── AuthRepositoryProtocol   ← feature modules and future AuthFlow UI
    └── AuthRepository           ← composition root / network implementation

AuthRepository
    └── AuthRepositoryProtocol

AuthRepositoryProtocol
    └── Foundation only
```

### Source folders

```
Sources/AuthRepositoryProtocol/
├── AuthRepository.swift          AuthRepository protocol
├── AuthRepositoryError.swift
└── Models/                       LoginCredentials, RegisterCredentials, User, AuthSession

Sources/AuthRepository/
├── AuthRepository.swift          re-export entry point
├── NetworkAuthRepository.swift   actor implementation
└── Internal/                     AuthAPIClient, JSON DTOs (not public)

Tests/ mirror the same folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| AuthFlow UI (future) | `AuthRepositoryProtocol` | Protocol and models only |
| App composition root | `AuthRepository` | Wire `NetworkAuthRepository` at startup |
| Tests / mocks | `AuthRepositoryProtocol` | Mock `AuthRepository` without networking |

`AuthRepository` re-exports `AuthRepositoryProtocol` via `@_exported import`.

## Responsibilities

**AuthRepository owns:**

- Email/password register and login against the backend API
- In-memory `AuthSession` and `User` while authenticated
- Token refresh and best-effort server logout
- Mapping HTTP errors to `AuthRepositoryError`

**AuthRepository does not:**

- SwiftUI screens or navigation
- Keychain or persistent token storage (v1)
- Local vault unlock (`SecureCrypto` / `VaultSession`)
- Biometrics or OAuth

## v1 REST API contract

Base URL is configured at `NetworkAuthRepository` init (e.g. `https://api.example.com/v1`).

| Method | Path | Success | Body |
|--------|------|---------|------|
| POST | `/auth/register` | 201 | `{ email, password }` → user + tokens |
| POST | `/auth/login` | 200 | `{ email, password }` → user + tokens |
| POST | `/auth/logout` | 204 | `Authorization: Bearer <accessToken>` |
| POST | `/auth/refresh` | 200 | `{ refreshToken }` → tokens |

Error responses:

```json
{ "error": "invalid_credentials", "message": "..." }
```

## Products

- **AuthRepositoryProtocol** — `AuthRepository` protocol, credential/session models, `AuthRepositoryError`
- **AuthRepository** — `actor NetworkAuthRepository` default implementation

## Testing

```bash
cd Packages/AuthFlow && swift test
```

Network tests use `URLProtocol` stubs — no live backend required.
