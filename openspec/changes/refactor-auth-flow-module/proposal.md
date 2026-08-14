## Why

The AuthFlow module grew organically: login and register view models contain large monolithic async methods that duplicate vault-session establishment logic, views mix inline layout with duplicated sheet presentation for biometric enrollment, and localization is inconsistent (raw string keys vs `AuthFlowUILocalization`). This refactor improves maintainability, testability, and consistency without changing user-visible auth behavior.

## What Changes

- Add `AuthFlowDomainProtocol` and `AuthFlowDomain` package targets with protocol-based use cases and default implementations
- Extract shared vault-session establishment, login, register, unlock, biometric unlock, and online session restore logic into use cases
- Slim `DefaultLoginViewModel`, `DefaultRegisterViewModel`, and `DefaultUnlockViewModel` to orchestration-only
- Enable String Catalog generated symbols in `AuthFlowUI`; migrate all views and `AuthFlowErrorText` away from raw keys and remove `AuthFlowUILocalization`
- Refactor `LoginView`, `RegisterView`, and `UnlockView` bodies into `@ViewBuilder` section helpers
- Add `AuthRoute.biometricEnrollment`; present enrollment via `navigator.present(..., style: .sheet)` (NavigationHost pattern)
- Remove view-level `.sheet` and `pendingBiometricEnrollment` from login/register views; enrollment dismisses via `Navigating.dismissPresentation()`
- Add `navigator` to `DefaultRegisterViewModel` for enrollment presentation
- Move `NotesIndexStoreLifecycle` into domain as part of `EstablishVaultSessionUseCase`

## Capabilities

### New Capabilities

- `auth-flow-domain`: Protocol-based auth use cases (`LoginUseCase`, `RegisterUseCase`, `UnlockUseCase`, `EstablishVaultSessionUseCase`, `BiometricUnlockUseCase`, `RestoreOnlineSessionUseCase`) with default implementations in `AuthFlowDomain`

### Modified Capabilities

- `auth-flow-ui`: View section builders, String Catalog symbols, navigator-driven biometric enrollment, view models delegate to use cases, remove local sheet presentation
- `auth-flow-routes`: `AuthRoute.biometricEnrollment` case and route registration in `AuthNavigation`

## Impact

- `Packages/AuthFlow/Package.swift` — new `AuthFlowDomainProtocol` and `AuthFlowDomain` targets and products; updated dependency graph
- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — view models slimmed; `NotesIndexStoreLifecycle` removed or relocated
- `Packages/AuthFlow/Sources/AuthFlowUI/` — view refactors, localization migration, `AuthNavigation` extension, enrollment navigation
- `Packages/AuthFlow/Sources/AuthFlowRoutes/` — new `AuthRoute` case
- `Packages/AuthFlow/Tests/` — new domain tests; updated view model, UI, and navigation tests
- No app composition root changes expected beyond dependency wiring for use cases
