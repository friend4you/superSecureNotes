## 1. Package and domain scaffolding

- [ ] 1.1 Add `AuthFlowDomainProtocol` and `AuthFlowDomain` targets, products, and test targets to `Packages/AuthFlow/Package.swift`
- [ ] 1.2 Add `EstablishVaultSessionPolicy`, result types, and use case protocol stubs in `AuthFlowDomainProtocol`
- [ ] 1.3 Wire `AuthFlowProtocol` dependency on `AuthFlowDomainProtocol`

## 2. EstablishVaultSessionUseCase

- [ ] 2.1 Write failing tests: standard unlock establishes session and opens index (`EstablishVaultSessionUseCaseTests`)
- [ ] 2.2 Write failing tests: first login with remote header pulls catalogs before establish
- [ ] 2.3 Write failing tests: index open failure clears vault session
- [ ] 2.4 Implement `DefaultEstablishVaultSessionUseCase` (migrate logic from `NotesIndexStoreLifecycle`)
- [ ] 2.5 Remove `NotesIndexStoreLifecycle.swift` from `AuthFlowProtocol` once use case covers all paths

## 3. RestoreOnlineSessionUseCase

- [ ] 3.1 Write failing tests: restore succeeds with refresh token (`RestoreOnlineSessionUseCaseTests`)
- [ ] 3.2 Write failing tests: restore failure retries login; network errors ignored
- [ ] 3.3 Implement `DefaultRestoreOnlineSessionUseCase` (migrate `AuthSessionRestoreHelper` usage from unlock)

## 4. BiometricUnlockUseCase

- [ ] 4.1 Write failing tests: success returns password; unavailable/cancelled require password entry (`BiometricUnlockUseCaseTests`)
- [ ] 4.2 Implement `DefaultBiometricUnlockUseCase`

## 5. LoginUseCase

- [ ] 5.1 Write failing tests: empty credentials, offline first setup, wasFirstSetup, invalid credentials mapping (`LoginUseCaseTests`) — port scenarios from `DefaultLoginViewModelTests`
- [ ] 5.2 Write failing tests: remote header pull branch and catalog sync policy
- [ ] 5.3 Implement `DefaultLoginUseCase`

## 6. RegisterUseCase

- [ ] 6.1 Write failing tests: empty credentials, upload failure clears session, wasFirstSetup (`RegisterUseCaseTests`) — port from `DefaultRegisterViewModelTests`
- [ ] 6.2 Implement `DefaultRegisterUseCase`

## 7. UnlockUseCase

- [ ] 7.1 Write failing tests: online restore invoked, flush pending when online, vault unlock failure (`UnlockUseCaseTests`) — port from `DefaultUnlockViewModelVaultTests`
- [ ] 7.2 Implement `DefaultUnlockUseCase`

## 8. Slim view models to use cases

- [ ] 8.1 Write failing tests: `DefaultLoginViewModel` delegates to `LoginUseCase` and presents enrollment on wasFirstSetup (`DefaultLoginViewModelTests` updates)
- [ ] 8.2 Refactor `DefaultLoginViewModel` — remove direct repository orchestration and enrollment state properties
- [ ] 8.3 Write failing tests: `DefaultRegisterViewModel` delegates to `RegisterUseCase`, has navigator, presents enrollment (`DefaultRegisterViewModelTests` updates)
- [ ] 8.4 Refactor `DefaultRegisterViewModel` — add navigator injection; remove enrollment state properties
- [ ] 8.5 Write failing tests: `DefaultUnlockViewModel` delegates to unlock/biometric use cases (`DefaultUnlockViewModelBioTests` / vault tests updates)
- [ ] 8.6 Refactor `DefaultUnlockViewModel` to use case protocols
- [ ] 8.7 Update `AuthFlowDependencies` to construct use cases and inject into view models

## 9. AuthRoute and navigator enrollment

- [ ] 9.1 Write failing test: `AuthRoute` includes `biometricEnrollment` (`AuthRouteTests`)
- [ ] 9.2 Add `biometricEnrollment` case to `AuthRoute`
- [ ] 9.3 Write failing test: `AuthNavigation` builds `BiometricEnrollmentView` for enrollment route (`AuthNavigationTests`)
- [ ] 9.4 Extend `AuthNavigation.view(for:deps:)` and route registry for enrollment
- [ ] 9.5 Write failing tests: enrollment VM dismisses via `navigator.dismissPresentation()` on skip/enable (`BiometricEnrollmentViewModelTests`)
- [ ] 9.6 Refactor `DefaultBiometricEnrollmentViewModel` — inject `Navigating`, remove `onComplete`; update `AuthFlowDependencyProviding.makeBiometricEnrollmentViewModel`
- [ ] 9.7 Update `BiometricEnrollmentViewTests` and remove sheet assertions from login/register view tests

## 10. View refactors (login, register, unlock)

- [ ] 10.1 Write failing structural tests: `LoginView` has section builders and no enrollment sheet (`LoginViewTests`)
- [ ] 10.2 Refactor `LoginView` body into `credentialsSection`, `errorSection`, `actionsSection`
- [ ] 10.3 Write failing structural tests: `RegisterView` has section builders and no enrollment sheet (`RegisterViewTests` / routing tests)
- [ ] 10.4 Refactor `RegisterView` body into section builders
- [ ] 10.5 Write failing structural tests: `UnlockView` has section builders (`UnlockViewTests`)
- [ ] 10.6 Refactor `UnlockView` body into section builders

## 11. String Catalog symbols

- [ ] 11.1 Enable `STRING_CATALOG_GENERATE_SYMBOLS` for `AuthFlowUI` target; verify symbols compile in a smoke test
- [ ] 11.2 Write failing test: views do not reference `AuthFlowUILocalization` or raw `String(localized: "key", bundle: .module)` (`LocalizationTests` updates)
- [ ] 11.3 Migrate `LoginView`, `RegisterView`, `UnlockView`, `BiometricEnrollmentView`, and `BiometricSettingsView` to generated symbols
- [ ] 11.4 Migrate `AuthFlowErrorText` to generated symbols
- [ ] 11.5 Remove `AuthFlowUILocalization.swift`; update `AuthFlowUIBundleTesting` if needed

## 12. Verification

- [ ] 12.1 Run full `AuthFlow` package test suite; fix regressions
- [ ] 12.2 Run app composition tests if `AuthFlowDependencies` signature changed
- [ ] 12.3 Manual smoke: first-time login and register show enrollment sheet via navigator; skip/enable dismisses; repeat login skips enrollment
