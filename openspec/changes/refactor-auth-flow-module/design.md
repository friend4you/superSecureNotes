## Context

AuthFlow currently spans repository, protocol, routes, and UI targets. Login (`DefaultLoginViewModel.login`), register (`DefaultRegisterViewModel.register`), and unlock (`DefaultUnlockViewModel.performUnlock`) each orchestrate auth repository calls, vault unlock, notes index lifecycle, and credential persistence inline. Biometric enrollment after first-time login/register uses duplicated `.sheet` bindings in `LoginView` and `RegisterView` with `pendingBiometricEnrollment` on view models.

The app already uses global sheet presentation via `NavigationHost` for cross-module flows (e.g. ShareNote). Auth enrollment should follow the same pattern.

## Goals / Non-Goals

**Goals:**

- Introduce `AuthFlowDomainProtocol` + `AuthFlowDomain` following the project's protocol/implementation split
- Replace monolithic view model methods with protocol-based use cases testable without full view models
- Consolidate duplicated vault + notes index establishment into `EstablishVaultSessionUseCase`
- Present biometric enrollment through `AuthRoute` + `navigator.present(..., .sheet)`
- Unify localization on String Catalog generated symbols; remove `AuthFlowUILocalization`
- Refactor auth SwiftUI views to section-builder style bodies

**Non-Goals:**

- Changing auth API contracts (`AuthRepository`, `VaultRepository`, etc.)
- New user-facing features (OAuth, forgot password, account switch)
- Moving view model protocols out of `AuthFlowProtocol`
- Refactoring `BiometricSettingsView` beyond localization consistency if touched

## Decisions

### 1. Domain target split: `AuthFlowDomainProtocol` + `AuthFlowDomain`

Mirror `AuthRepositoryProtocol` / `AuthRepository`. Protocols and result types live in `AuthFlowDomainProtocol` with minimal dependencies (`AuthRepositoryProtocol`, `CredentialStoreProtocol`, `VaultRepositoryProtocol`, `VaultSessionProtocol`, `NoteRepositoryProtocol`, `NetworkProtocol`). Default implementations live in `AuthFlowDomain`.

`AuthFlowProtocol` view models depend on use case protocols, not concrete domain types directly in public API.

### 2. Use case protocols (not structs)

Each use case is a `@MainActor` protocol with a single `execute` method and a `Default*` implementation:

| Protocol | Responsibility |
|----------|----------------|
| `EstablishVaultSessionUseCase` | Unlock vault + open notes index + establish session; absorbs `NotesIndexStoreLifecycle` |
| `LoginUseCase` | Validate, network check, auth login, header pull branch, establish session, save setup; returns `wasFirstSetup` |
| `RegisterUseCase` | Validate, network check, register, create/upload vault, establish session, save setup; returns `wasFirstSetup` |
| `UnlockUseCase` | Optional online restore, vault unlock + establish, flush pending sync when online |
| `BiometricUnlockUseCase` | LA prompt + load password from credential store |
| `RestoreOnlineSessionUseCase` | Session restore with login fallback; absorbs `AuthSessionRestoreHelper` logic |

`EstablishVaultSessionUseCase` accepts a policy enum for login's three branches (`firstLoginWithRemoteHeader`, `afterLocalCreate`, `standardUnlock`) instead of duplicating lifecycle calls in login/register/unlock.

**Alternative considered:** Single `AuthenticateUseCase` for login+register — rejected because register's create/upload path is meaningfully different.

### 3. Biometric enrollment via navigator (Option A)

After first-time login/register success, view model calls:

```swift
navigator.present(AuthRoute.biometricEnrollment, style: .sheet)
```

`AuthNavigation` maps `.biometricEnrollment` to `BiometricEnrollmentView`. `DefaultBiometricEnrollmentViewModel` receives `Navigating` and calls `dismissPresentation()` on skip/enable instead of an `onComplete` closure from login/register.

Remove from login/register views:
- `.sheet(isPresented:)`
- `biometricEnrollmentSheetBinding`
- `pendingBiometricEnrollment`, `makeBiometricEnrollmentViewModel()`, `dismissBiometricEnrollment()`

`DefaultRegisterViewModel` gains `navigator: any Navigating` injection (login already has it).

### 4. String Catalog generated symbols

Enable `STRING_CATALOG_GENERATE_SYMBOLS` for `AuthFlowUI` target. Views use generated symbols (e.g. `Text(.loginEmail)`) and `AuthFlowErrorText` maps errors to generated symbols. Remove `AuthFlowUILocalization.swift`. Keep `AuthFlowUIBundleTesting` / localization tests verifying catalog bundling.

**Alternative considered:** Keep wrapper enum — rejected per decision to use symbols directly.

### 5. View body structure

Each auth form view (`LoginView`, `RegisterView`, `UnlockView`) body contains only:
- `Form { credentialsSection; errorSection; actionsSection }`
- modifiers (`navigationTitle`, `onAppear`)
- no sheet modifiers

Private `@ViewBuilder` properties for each section. Unlock retains conditional logic (`showsPasswordField`, `showsBiometricRetry`) in section builders or small computed helpers.

### 6. View models remain in `AuthFlowProtocol`

Use cases live in domain; view models stay in protocol target and become thin orchestrators setting `state`, calling use cases, and triggering navigation.

### 7. Unlock use case scope

Unlock view model already has clear private methods. Extract shared `EstablishVaultSessionUseCase` and `RestoreOnlineSessionUseCase` + `BiometricUnlockUseCase` rather than mirroring login's full split. Do not over-split unlock into one protocol per private method.

## Risks / Trade-offs

- **[Risk] SPM String Catalog symbol generation** — may require Xcode build settings on `AuthFlowUI` target → verify in CI/local build early in implementation
- **[Risk] Enrollment sheet stacks with auth NavigationStack** — enrollment view already wraps `NavigationStack`; sheet presentation via `NavigationHost` should work as with ShareNote → manual QA on first-setup login/register
- **[Risk] Login first-setup branch complexity** — `EstablishVaultSessionPolicy` must preserve exact behavior for pull-header + catalog sync path → port existing tests before refactoring implementation
- **[Trade-off] More types/files** — improved testability and less duplication; acceptable for auth-critical paths
- **[Trade-off] `AuthFlowDependencyProviding.makeBiometricEnrollmentViewModel(onComplete:)`** — signature changes to remove `onComplete`; enrollment VM factory uses navigator from deps

## Migration Plan

1. Add domain targets and use case protocols (no view model changes)
2. Port tests to use cases with existing behavior as oracle
3. Slim view models to delegate to use cases
4. Add route + navigation for enrollment; switch presentation
5. Localization + view refactors (can parallelize after enrollment navigation lands)
6. Remove dead code (`NotesIndexStoreLifecycle`, `AuthFlowUILocalization`, sheet bindings)

No data migration. Rollback: revert package commit; no persisted schema changes.

## Open Questions

None — decisions confirmed in exploration:
- Enrollment: navigator Option A
- Domain: `AuthFlowDomainProtocol` + `AuthFlowDomain`
- Use cases: protocols with default implementations
- Scope: all three auth form views in one change
