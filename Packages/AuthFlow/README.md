# AuthFlow

Swift package providing server account authentication, session persistence, biometric unlock, and auth UI for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── AuthFlowUI              ← SwiftUI auth/unlock/settings screens
    ├── AuthFlowProtocol        ← ViewModel contracts and orchestration types
    ├── CredentialStore         ← Keychain-backed credential persistence
    ├── AuthRepository          ← network implementation
    └── AuthRepositoryProtocol  ← repository contracts

AuthFlowUI
    ├── AuthFlowProtocol
    ├── AuthFlowRoutes
    └── SecureCrypto            (SecureCryptoVaultAuthenticator only)

AuthFlowProtocol
    ├── AuthRepositoryProtocol
    ├── CredentialStoreProtocol
    ├── VaultRepositoryProtocol
    └── VaultSessionProtocol

CredentialStore
    └── CredentialStoreProtocol

AuthRepository
    ├── AuthRepositoryProtocol
    └── VaultRepositoryProtocol (AccessTokenProviding adapter)

AuthRepositoryProtocol
    └── Foundation only

CredentialStoreProtocol
    └── Foundation only
```

### Source folders

```
Sources/CredentialStoreProtocol/
├── CredentialStore.swift           protocol + CredentialStoreError
└── CredentialStoreProtocol.swift   re-export entry point

Sources/CredentialStore/
├── CredentialStore.swift           re-export entry point
├── KeychainCredentialStore.swift
└── Internal/                       Keychain access helpers

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
├── AuthFlowDependencies.swift
├── AuthSessionRestoreHelper.swift
├── LogoutReset.swift
├── Models/
│   └── AuthFormState.swift           AuthFormState, AuthFlowError, UnlockFormState
├── Protocols/
│   ├── LoginViewModel.swift
│   ├── RegisterViewModel.swift
│   ├── UnlockViewModel.swift
│   ├── BiometricAuthenticator.swift
│   ├── BiometricEnrollmentViewModel.swift
│   ├── NetworkReachability.swift
│   └── VaultAuthenticator.swift
├── ViewModels/
│   ├── DefaultLoginViewModel.swift
│   ├── DefaultRegisterViewModel.swift
│   ├── DefaultUnlockViewModel.swift
│   ├── DefaultBiometricEnrollmentViewModel.swift
│   └── DefaultBiometricSettingsViewModel.swift
└── Internal/
    └── AuthFlowErrorMapper.swift

Sources/AuthFlowUI/
├── AuthFlowUI.swift                  re-export entry point
├── Views/
│   ├── LoginView.swift
│   ├── RegisterView.swift
│   ├── UnlockView.swift
│   ├── BiometricEnrollmentView.swift
│   └── BiometricSettingsView.swift
├── Authenticators/
│   ├── SecureCryptoVaultAuthenticator.swift
│   └── LocalAuthenticationBiometricAuthenticator.swift
├── Navigation/
│   └── AuthNavigation.swift
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
| App composition root | `AuthFlowUI`, `CredentialStore`, `AuthRepository`, `VaultRepository`, `VaultSession` | Wire dependencies, Keychain store, and present auth screens |
| Feature modules | `AuthFlowProtocol`, `CredentialStoreProtocol` | ViewModel protocols without SwiftUI |
| Tests / mocks | `AuthFlowProtocol`, `AuthRepositoryProtocol`, `CredentialStoreProtocol` | Mock contracts without networking, Keychain, or UI |

`AuthRepository`, `CredentialStore`, and `AuthFlowUI` re-export their protocol modules via `@_exported import`.

## Session persistence

**CredentialStore owns:**

- `hasLocalSetup` flag — `false` on first launch, `true` after first successful login/register
- Email, refresh token, and vault header cache in Keychain (`whenUnlockedThisDeviceOnly`)
- Bio-gated password item (`biometryCurrentSet`) when biometrics are enabled
- `saveSetup(email:refreshToken:vaultHeader:)` for atomic first-time setup
- `clearAll()` for full logout reset

**App layer owns:**

- `LockCoordinator` — clears `VaultSession` and in-memory auth on background / device lock; Keychain unchanged
- `SessionRootNavigation` — three root states: login (`!hasLocalSetup`), unlock (`hasLocalSetup && !vaultActive`), notes (`vaultActive`)
- `NWPathNetworkReachability` — blocks first-time login/register when offline

**AuthFlowProtocol owns:**

- `AuthSessionRestoreHelper` — loads refresh token from `CredentialStore` and calls `restoreSession` during online unlock
- `LogoutReset` — clears auth memory, vault session, and Keychain (credential store cleared before vault so root navigation routes to login)

## Lock and unlock

**Lock (app target):**

1. User backgrounds app or device locks
2. `LockCoordinator` calls `vaultSession.clear()` and `authRepository.clearSession()`
3. Navigation switches to `AuthRoute.unlock` (Keychain credentials preserved)

**Unlock (`DefaultUnlockViewModel`):**

1. Bio prompt when `bioEnabled` (password retrieved from Keychain on success)
2. Password entry fallback with read-only email
3. Online: `AuthSessionRestoreHelper.restoreSession` using persisted refresh token; on failure, soft error and re-login with entered password
4. Offline: skip server restore
5. Read vault header from `CredentialStore`, `VaultAuthenticator.unlockVault`, `vaultSession.establish()`

Bio/password is always required for vault unlock even when refresh succeeds.

## Biometrics

**Enrollment (one-time after first setup):**

- `LoginView` / `RegisterView` present `BiometricEnrollmentView` sheet when `pendingBiometricEnrollment` is true
- User can enable (password confirmation) or skip ("Not Now")
- Not shown again on subsequent unlocks

**Settings:**

- `BiometricSettingsView` toggle in Settings (`AuthRoute.settings`)
- Enabling requires password confirmation; disabling removes bio-gated Keychain item

**Unlock:**

- `LocalAuthenticationBiometricAuthenticator` wraps `LAContext`
- Bio-first when enabled; failed/cancelled bio falls back to password screen

## Auth UI responsibilities

**AuthFlowUI owns:**

- `LoginView`, `RegisterView`, `UnlockView`, `BiometricEnrollmentView`, `BiometricSettingsView`
- Localized strings from `Localizable.xcstrings` (`login.*`, `register.*`, `unlock.*`, `bio.*`)
- `SecureCryptoVaultAuthenticator` and `LocalAuthenticationBiometricAuthenticator`

**AuthFlowProtocol owns:**

- Login/register/unlock/biometric ViewModel orchestration
- Register flow: account auth → create vault → upload header → establish `VaultSession` → persist setup
- Login flow: account auth → fetch header → unlock vault → establish `VaultSession` → persist setup
- First-launch internet gate via `NetworkReachability`

**AuthFlowUI does not:**

- Own app-wide lock lifecycle (`LockCoordinator` lives in app target)
- Display recovery mnemonic (v1)

## Localization

All user-visible strings live in `AuthFlowUI/Resources/Localizable.xcstrings`. Views resolve copy via `AuthFlowUILocalization` or `bundle: .module`. ViewModels expose `AuthFlowError` cases; views map errors to localized strings.

## Repository responsibilities

**AuthRepository owns:**

- Email/password register and login against the backend API
- In-memory `AuthSession` and `User` while authenticated
- Token refresh, session restore, and best-effort server logout
- `AuthRepositoryAccessTokenProvider` for `VaultRepository` bearer tokens

Refresh token persistence is handled by `CredentialStore`; access token is restored in memory on unlock only.

## v1 REST API contract

Base URL is configured at repository init (e.g. `https://api.example.com/v1`).

| Method | Path | Success | Body |
|--------|------|---------|------|
| POST | `/auth/register` | 201 | `{ email, password }` → user + tokens |
| POST | `/auth/login` | 200 | `{ email, password }` → user + tokens |
| POST | `/auth/logout` | 204 | `Authorization: Bearer <accessToken>` |
| POST | `/auth/refresh` | 200 | `{ refreshToken }` → tokens |

## Products

- **CredentialStoreProtocol** — `CredentialStore` protocol and error types
- **CredentialStore** — `KeychainCredentialStore` implementation
- **AuthRepositoryProtocol** — repository contracts and models
- **AuthRepository** — `NetworkAuthRepository` and token provider adapter
- **AuthFlowRoutes** — `AuthRoute` (login, register, unlock, settings)
- **AuthFlowProtocol** — ViewModel protocols, state types, default ViewModels, session restore
- **AuthFlowUI** — SwiftUI screens, localization, crypto and biometric authenticators

## Testing

```bash
cd Packages/AuthFlow && swift test
```

ViewModel tests use mock repositories, credential stores, and authenticators. `CredentialStoreTests` use isolated Keychain service names per test. Network tests use `URLProtocol` stubs — no live backend required.

App-target lock and navigation tests live in `superSecureNotesTests/` (`LockCoordinatorTests`, `SessionRootNavigationTests`).
