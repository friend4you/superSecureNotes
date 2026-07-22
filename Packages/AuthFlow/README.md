# AuthFlow

Swift package providing server account authentication and auth UI for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── AuthFlowUI              ← SwiftUI login/register screens
    ├── AuthFlowProtocol        ← ViewModel contracts and orchestration types
    ├── AuthRepository          ← network implementation
    └── AuthRepositoryProtocol  ← repository contracts

AuthFlowUI
    ├── AuthFlowProtocol
    └── SecureCrypto            (SecureCryptoVaultAuthenticator only)

AuthFlowProtocol
    ├── AuthRepositoryProtocol
    ├── VaultRepositoryProtocol
    └── VaultSessionProtocol

AuthRepository
    ├── AuthRepositoryProtocol
    └── VaultRepositoryProtocol (AccessTokenProviding adapter)

AuthRepositoryProtocol
    └── Foundation only
```

### Source folders

```
Sources/AuthRepositoryProtocol/
├── AuthRepository.swift
├── AuthRepositoryError.swift
└── Models/

Sources/AuthRepository/
├── AuthRepository.swift              re-export entry point
├── NetworkAuthRepository.swift
├── Adapters/
│   └── AuthRepositoryAccessTokenProvider.swift
└── Internal/                         AuthAPIClient, JSON DTOs (not public)

Sources/AuthFlowProtocol/
├── AuthFlowProtocol.swift
├── Models/
│   └── AuthFormState.swift           AuthFormState, AuthFlowError
├── Protocols/
│   ├── LoginViewModel.swift
│   ├── RegisterViewModel.swift
│   └── VaultAuthenticator.swift
├── ViewModels/
│   ├── DefaultLoginViewModel.swift
│   └── DefaultRegisterViewModel.swift
└── Internal/
    └── AuthFlowErrorMapper.swift

Sources/AuthFlowUI/
├── AuthFlowUI.swift                  re-export entry point
├── Views/
│   ├── LoginView.swift
│   └── RegisterView.swift
├── Authenticators/
│   └── SecureCryptoVaultAuthenticator.swift
├── Localization/
│   ├── AuthFlowErrorText.swift
│   ├── AuthFlowUILocalization.swift
│   └── AuthFlowUIBundleTesting.swift
├── Preview/
│   └── PreviewSupport.swift
└── Resources/
    └── Localizable.xcstrings

Tests/ mirror the same folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| App composition root | `AuthFlowUI`, `AuthRepository`, `VaultRepository`, `VaultSession` | Wire dependencies and present auth screens |
| Feature modules | `AuthFlowProtocol` | ViewModel protocols without SwiftUI |
| Tests / mocks | `AuthFlowProtocol`, `AuthRepositoryProtocol` | Mock contracts without networking or UI |

`AuthRepository` and `AuthFlowUI` re-export their protocol modules via `@_exported import`.

## Auth UI responsibilities

**AuthFlowUI owns:**

- `LoginView` and `RegisterView` with localized strings from `Localizable.xcstrings`
- `SecureCryptoVaultAuthenticator` default `VaultAuthenticator` implementation
- SwiftUI previews for auth screens

**AuthFlowProtocol owns:**

- `LoginViewModel` / `RegisterViewModel` protocols
- `DefaultLoginViewModel` / `DefaultRegisterViewModel` orchestration
- Register flow: account auth → create vault → upload header → establish `VaultSession`
- Login flow: account auth → fetch header → unlock vault → establish `VaultSession`

**AuthFlowUI does not:**

- Own app-wide navigation beyond login ↔ register
- Display recovery mnemonic (v1)
- Persist tokens to Keychain

## Localization

All user-visible strings live in `AuthFlowUI/Resources/Localizable.xcstrings`. Views resolve copy via `bundle: .module`. ViewModels expose `AuthFlowError` cases; views map errors to localized strings.

## Repository responsibilities

**AuthRepository owns:**

- Email/password register and login against the backend API
- In-memory `AuthSession` and `User` while authenticated
- Token refresh and best-effort server logout
- `AuthRepositoryAccessTokenProvider` for `VaultRepository` bearer tokens

## v1 REST API contract

Base URL is configured at repository init (e.g. `https://api.example.com/v1`).

| Method | Path | Success | Body |
|--------|------|---------|------|
| POST | `/auth/register` | 201 | `{ email, password }` → user + tokens |
| POST | `/auth/login` | 200 | `{ email, password }` → user + tokens |
| POST | `/auth/logout` | 204 | `Authorization: Bearer <accessToken>` |
| POST | `/auth/refresh` | 200 | `{ refreshToken }` → tokens |

## Products

- **AuthRepositoryProtocol** — repository contracts and models
- **AuthRepository** — `NetworkAuthRepository` and token provider adapter
- **AuthFlowProtocol** — ViewModel protocols, state types, default ViewModels
- **AuthFlowUI** — SwiftUI screens, localization, crypto authenticator

## Testing

```bash
cd Packages/AuthFlow && swift test
```

ViewModel tests use mock repositories and authenticators. Network tests use `URLProtocol` stubs — no live backend required.
