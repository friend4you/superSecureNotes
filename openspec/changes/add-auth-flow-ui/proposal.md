## Why

`AuthRepository`, `VaultRepository`, and `SecureCrypto` provide the backend contracts for account auth and vault lifecycle, but the app still has no login or registration UI. Users cannot reach note flows without screens that orchestrate account authentication, vault create/unlock, and session establishment. This change delivers the `AuthFlow` UI layer that was explicitly deferred in `add-auth-flow-repository`, with strict TDD on ViewModels and localized user-facing strings.

## What Changes

- Extend `Packages/AuthFlow/` with two new library products: `AuthFlowProtocol` (ViewModel contracts, state types, vault orchestration protocol) and `AuthFlowUI` (SwiftUI views, default ViewModels, localization)
- Add public `LoginView` and `RegisterView` with email and password fields, loading/error states, and navigation link between screens
- Implement `DefaultLoginViewModel` and `DefaultRegisterViewModel` that orchestrate `AuthRepository`, `VaultRepository`, `VaultAuthenticator`, and `VaultSessionProtocol`
- Add `Localizable.xcstrings` in `AuthFlowUI` — all user-visible strings SHALL come from the catalog (no hardcoded display strings in views)
- Wire app composition root: present `LoginView` when unauthenticated; inject concrete repository and crypto dependencies
- Add `AuthRepository` → `AccessTokenProviding` adapter for `VaultRepository` bearer tokens
- Strict TDD: failing ViewModel tests before each implementation task

## Capabilities

### New Capabilities

- `auth-flow-ui`: Auth UI package boundary, ViewModel protocols, login/register screens, vault orchestration on auth success, localization, app entry wiring

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/AuthFlow/` — new `AuthFlowProtocol` and `AuthFlowUI` targets, products, tests, and `Localizable.xcstrings`
- `Packages/AuthFlow/Package.swift` — package dependencies on `AuthRepositoryProtocol`, `VaultRepository`, `SecureCrypto`, `VaultSession`
- `superSecureNotes.xcodeproj` — link `AuthFlowUI` to app target; wire dependencies at composition root
- `superSecureNotes/` — app root presents `LoginView` when no active auth + vault session
- Out of scope: recovery-key screen, forgot password, biometrics, Keychain token persistence, OAuth, note list gating beyond showing auth entry
