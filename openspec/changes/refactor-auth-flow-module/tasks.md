## 1. Package and domain scaffolding

- [x] 1.1 Add `AuthFlowDomainProtocol` and `AuthFlowDomain` targets, products, and test targets to `Packages/AuthFlow/Package.swift`
- [x] 1.2 Add `EstablishVaultSessionPolicy`, result types, and use case protocol stubs in `AuthFlowDomainProtocol`
- [x] 1.3 Wire `AuthFlowProtocol` dependency on `AuthFlowDomainProtocol`

## 2. EstablishVaultSessionUseCase

- [x] 2.1 Write failing tests: standard unlock establishes session and opens index (`EstablishVaultSessionUseCaseTests`)
- [x] 2.2 Write failing tests: first login with remote header pulls catalogs before establish
- [x] 2.3 Write failing tests: index open failure clears vault session
- [x] 2.4 Implement `DefaultEstablishVaultSessionUseCase` (migrate logic from `NotesIndexStoreLifecycle`)
- [x] 2.5 Remove `NotesIndexStoreLifecycle.swift` from `AuthFlowProtocol` once use case covers all paths

## 3. RestoreOnlineSessionUseCase

- [x] 3.1 Write failing tests: restore succeeds with refresh token (`RestoreOnlineSessionUseCaseTests`)
- [x] 3.2 Write failing tests: restore failure retries login; network errors ignored
- [x] 3.3 Implement `DefaultRestoreOnlineSessionUseCase` (migrate `AuthSessionRestoreHelper` usage from unlock)

## 4. BiometricUnlockUseCase

- [x] 4.1 Write failing tests: success returns password; unavailable/cancelled require password entry (`BiometricUnlockUseCaseTests`)
- [x] 4.2 Implement `DefaultBiometricUnlockUseCase`

## 5. LoginUseCase

- [x] 5.1 Write failing tests: empty credentials, offline first setup, wasFirstSetup, invalid credentials mapping (`LoginUseCaseTests`) — port scenarios from `DefaultLoginViewModelTests`
- [x] 5.2 Write failing tests: remote header pull branch and catalog sync policy
- [x] 5.3 Implement `DefaultLoginUseCase`

## 6. RegisterUseCase

- [x] 6.1 Write failing tests: empty credentials, upload failure clears session, wasFirstSetup (`RegisterUseCaseTests`) — port from `DefaultRegisterViewModelTests`
- [x] 6.2 Implement `DefaultRegisterUseCase`

## 7. UnlockUseCase

- [x] 7.1 Write failing tests: online restore invoked, flush pending when online, vault unlock failure (`UnlockUseCaseTests`) — port from `DefaultUnlockViewModelVaultTests`
- [x] 7.2 Implement `DefaultUnlockUseCase`

## 8. Slim view models to use cases

- [x] 8.1 Write failing tests: `DefaultLoginViewModel` delegates to `LoginUseCase` and presents enrollment on wasFirstSetup (`DefaultLoginViewModelTests` updates)
- [x] 8.2 Refactor `DefaultLoginViewModel` — remove direct repository orchestration and enrollment state properties
- [x] 8.3 Write failing tests: `DefaultRegisterViewModel` delegates to `RegisterUseCase`, has navigator, presents enrollment (`DefaultRegisterViewModelTests` updates)
- [x] 8.4 Refactor `DefaultRegisterViewModel` — add navigator injection; remove enrollment state properties
- [x] 8.5 Write failing tests: `DefaultUnlockViewModel` delegates to unlock/biometric use cases (`DefaultUnlockViewModelBioTests` / vault tests updates)
- [x] 8.6 Refactor `DefaultUnlockViewModel` to use case protocols
- [x] 8.7 Update `AuthFlowDependencies` to construct use cases and inject into view models

## 9. AuthRoute and navigator enrollment

- [x] 9.1 Write failing test: `AuthRoute` includes `biometricEnrollment` (`AuthRouteTests`)
- [x] 9.2 Add `biometricEnrollment` case to `AuthRoute`
- [x] 9.3 Write failing test: `AuthNavigation` builds `BiometricEnrollmentView` for enrollment route (`AuthNavigationTests`)
- [x] 9.4 Extend `AuthNavigation.view(for:deps:)` and route registry for enrollment
- [x] 9.5 Write failing tests: enrollment VM dismisses via `navigator.dismissPresentation()` on skip/enable (`BiometricEnrollmentViewModelTests`)
- [x] 9.6 Refactor `DefaultBiometricEnrollmentViewModel` — inject `Navigating`, remove `onComplete`; update `AuthFlowDependencyProviding.makeBiometricEnrollmentViewModel`
- [x] 9.7 Update `BiometricEnrollmentViewTests` and remove sheet assertions from login/register view tests

## 10. View refactors (login, register, unlock)

- [x] 10.1 Write failing structural tests: `LoginView` has section builders and no enrollment sheet (`LoginViewTests`)
- [x] 10.2 Refactor `LoginView` body into `credentialsSection`, `errorSection`, `actionsSection`
- [x] 10.3 Write failing structural tests: `RegisterView` has section builders and no enrollment sheet (`RegisterViewTests` / routing tests)
- [x] 10.4 Refactor `RegisterView` body into section builders
- [x] 10.5 Write failing structural tests: `UnlockView` has section builders (`UnlockViewTests`)
- [x] 10.6 Refactor `UnlockView` body into section builders

## 11. String Catalog symbols

- [ ] 11.1 Enable `STRING_CATALOG_GENERATE_SYMBOLS` for `AuthFlowUI` target; verify symbols compile in a smoke test
- [x] 11.2 Write failing test: views do not reference `AuthFlowUILocalization` (`LocalizationTests` updates)
- [ ] 11.3 Migrate `LoginView`, `RegisterView`, `UnlockView`, `BiometricEnrollmentView`, and `BiometricSettingsView` to generated symbols
- [ ] 11.4 Migrate `AuthFlowErrorText` to generated symbols
- [x] 11.5 Remove `AuthFlowUILocalization.swift`; update `AuthFlowUIBundleTesting` if needed

## 12. Verification

- [x] 12.1 Run full `AuthFlow` package test suite; fix regressions
- [x] 12.2 Run app composition tests if `AuthFlowDependencies` signature changed
- [ ] 12.3 Manual smoke: first-time login and register show enrollment sheet via navigator; skip/enable dismisses; repeat login skips enrollment
