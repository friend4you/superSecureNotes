## 1. Session Password Cache

- [ ] 1.1 Write failing tests: `SessionPasswordCache` stores password on `store`, returns on `password`, returns nil after `clear` (`AuthFlowProtocolTests/SessionPasswordCacheTests.swift` — scenarios: Login populates session cache, Cache is empty when cleared)
- [ ] 1.2 Implement `SessionPasswordCache` in `AuthFlowProtocol`; make tests pass
- [ ] 1.3 Write failing tests: `LoginUseCase`, `RegisterUseCase`, and `UnlockUseCase` call cache `store` after successful vault establishment (`AuthFlowProtocolTests/Domain/LoginUseCaseTests.swift`, `RegisterUseCaseTests.swift`, `UnlockUseCaseTests.swift` — scenarios: Login/Register/Unlock populates session cache)
- [ ] 1.4 Wire `SessionPasswordCaching` into auth use cases via `AuthFlowDependencies`; make tests pass

## 2. Pending Biometric Enrollment Store

- [ ] 2.1 Write failing tests: `UserDefaultsPendingBiometricEnrollmentStore` persists flag across instances; `setPending(false)` clears (`AuthFlowProtocolTests/PendingBiometricEnrollmentStoreTests.swift` — scenarios: First setup sets pending flag, Skip clears pending flag, Pending flag survives app termination)
- [ ] 2.2 Implement `PendingBiometricEnrollmentStoring` + UserDefaults-backed store; make tests pass

## 3. Session Root Navigation Gating

- [ ] 3.1 Write failing tests: `SessionRootNavigation.apply` skips `setRoot(notes)` when pending enrollment is true even if vault active; navigates to notes when pending is false (`SessionRootNavigationTests.swift` — scenarios: Active vault with pending enrollment stays on auth root, Active vault without pending enrollment navigates to notes)
- [ ] 3.2 Extend `SessionRootNavigation.apply` with pending enrollment parameter; update `RootView` and `AppComposition.syncRootRoute` to pass flag; make tests pass
- [ ] 3.3 Write failing tests: `NavigationRouter.setRoot` during pending enrollment does not run while enrollment sheet is presented — integration via composition test (`superSecureNotesTests/BiometricEnrollmentGatingTests.swift` — scenario: setRoot does not dismiss enrollment sheet)
- [ ] 3.4 Wire pending store into root sync path; make tests pass

## 4. Login and Register Enrollment Flow

- [ ] 4.1 Write failing tests: first-time login/register sets pending flag before presenting enrollment; repeat login does not set flag (`DefaultLoginViewModelEnrollmentTests.swift`, `DefaultRegisterViewModelEnrollmentTests.swift` — scenarios: First setup sets pending flag, Repeat login does not present enrollment)
- [ ] 4.2 Update login/register view models to set pending before `present(biometricEnrollment)`; make tests pass
- [ ] 4.3 Write failing tests: enrollment skip/enable clears pending flag and triggers notes root navigation (`BiometricEnrollmentViewModelTests.swift` — scenarios: Skip clears pending flag, Enable clears pending flag, Notes navigation after enrollment dismissed)
- [ ] 4.4 Update `DefaultBiometricEnrollmentViewModel` to clear pending, use session cache for enable, and invoke root re-sync callback; make tests pass

## 5. Resume Enrollment After Unlock

- [ ] 5.1 Write failing tests: when pending flag is true after unlock, enrollment is presented before notes (`DefaultUnlockViewModelEnrollmentTests.swift` — scenarios: Enrollment shown after unlock when pending, No enrollment after unlock when not pending)
- [ ] 5.2 Add unlock-path enrollment presentation when pending; make tests pass
- [ ] 5.3 Write failing tests: lock during pending enrollment preserves flag and re-shows enrollment on next unlock (`superSecureNotesTests/BiometricEnrollmentGatingTests.swift` — scenario: Lock during enrollment resumes on next unlock)
- [ ] 5.4 Verify lock coordinator does not clear pending flag; make tests pass

## 6. Session Lock and Logout Cache Clearing

- [ ] 6.1 Write failing tests: lock clears session cache but not pending flag; logout clears both (`LockCoordinatorTests.swift`, `LogoutFlowTests.swift` — scenarios: Lock clears session cache, Lock preserves pending enrollment flag, Logout clears session password cache, Logout clears pending enrollment flag)
- [ ] 6.2 Wire cache clear into `LockCoordinator` and `LogoutReset`; make tests pass

## 7. Biometric Settings Password-Free Enable

- [ ] 7.1 Write failing tests: settings enable with populated cache enables bio without password field; empty cache shows fallback prompt (`BiometricSettingsViewModelTests.swift` — scenarios: Enable bio from Settings using session cache, Enable bio from Settings with password fallback)
- [ ] 7.2 Update `DefaultBiometricSettingsViewModel` to read session cache; make tests pass
- [ ] 7.3 Write failing structural tests: `BiometricSettingsView` shows password field only on fallback path (`BiometricSettingsViewTests.swift` — scenario: Password field conditional on requiresPasswordConfirmation)
- [ ] 7.4 Update `BiometricSettingsView` UI; make tests pass

## 8. Biometric Enrollment UI Simplification

- [ ] 8.1 Write failing structural tests: `BiometricEnrollmentView` omits password SecureField when cache available (`BiometricEnrollmentViewTests.swift` — scenario: Enrollment view omits password field on first setup)
- [ ] 8.2 Remove password field from `BiometricEnrollmentView`; enrollment VM reads from cache; make tests pass
- [ ] 8.3 Write failing tests: enable button stores cached password in Keychain (`BiometricEnrollmentViewModelTests.swift` — scenario: Enable button stores cached password)
- [ ] 8.4 Verify end-to-end enable path; make tests pass

## 9. Integration Verification

- [ ] 9.1 Write failing integration test: first-time register/login presents enrollment, vault becomes active, sheet survives, skip navigates to notes (`superSecureNotesTests/BiometricEnrollmentGatingTests.swift` — scenarios: Enrollment shown after first login, Notes navigation after enrollment dismissed)
- [ ] 9.2 Wire full composition and make integration test pass
- [ ] 9.3 Manual smoke: first-time register and login always show enrollment; skip and enable reach notes; settings toggle enables bio without password while unlocked; lock and unlock with pending flag re-shows enrollment
