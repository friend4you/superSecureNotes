## 1. Package Structure

- [x] 1.1 Extend `Packages/AuthFlow/Package.swift` with `CredentialStoreProtocol` and `CredentialStore` products/targets; add `CredentialStoreTests` test target
- [x] 1.2 Scaffold `Sources/CredentialStoreProtocol/` and `Sources/CredentialStore/` module entry points
- [x] 1.3 Add `CredentialStore` package product to Xcode project app target

## 2. CredentialStore Protocol and Error Types

- [x] 2.1 Write failing tests: `CredentialStore` protocol compiles; `CredentialStoreError` cases are `Equatable` and `Sendable` (`CredentialStoreTests/CredentialStoreProtocolTests.swift`)
- [x] 2.2 Add `CredentialStore` protocol and `CredentialStoreError` to `CredentialStoreProtocol`; make tests pass

## 3. Device Setup Flag

- [x] 3.1 Write failing tests: `hasLocalSetup` is `false` initially; `markSetupComplete()` sets `true`; `clearAll()` resets to `false` (`CredentialStoreTests/DeviceSetupFlagTests.swift` — scenarios: Initial state is not set up, Mark device set up after first auth, Clear all removes every item)
- [x] 3.2 Implement `hasLocalSetup` and `markSetupComplete()` in `KeychainCredentialStore`; make tests pass

## 4. Email and Refresh Token Persistence

- [x] 4.1 Write failing tests: save/read email and refresh token; cleared on `clearAll()` (`CredentialStoreTests/TokenPersistenceTests.swift` — scenarios: Save and read email, Save and read refresh token, Email cleared on full reset, Refresh token cleared on full reset)
- [x] 4.2 Implement email and refresh token Keychain items with `whenUnlockedThisDeviceOnly`; make tests pass

## 5. Vault Header Cache

- [x] 5.1 Write failing tests: save/read vault header `Data`; update on re-save; cleared on `clearAll()` (`CredentialStoreTests/VaultHeaderCacheTests.swift` — scenarios: Save and read vault header, Vault header updated on successful online unlock, Vault header cleared on full reset)
- [x] 5.2 Implement vault header Keychain item; make tests pass

## 6. Bio-Gated Password Storage

- [x] 6.1 Write failing tests: `bioEnabled` defaults `false`; `setBioEnabled(true)` + `savePassword` stores retrievable password; `setBioEnabled(false)` removes item (`CredentialStoreTests/BioPasswordTests.swift` — scenarios: Save password with biometrics enabled, Password item removed when biometrics disabled, Password not stored when biometrics never enabled, Bio flag updated on enable)
- [x] 6.2 Implement bio-gated password Keychain item with `biometryCurrentSet`; make tests pass (use test seam or mock `LAContext` wrapper)

## 7. Complete Setup Persistence

- [x] 7.1 Write failing tests: `saveSetup(email:refreshToken:vaultHeader:)` atomically persists all fields and sets `hasLocalSetup` (`CredentialStoreTests/SetupPersistenceTests.swift` — scenario: Save setup marks device ready)
- [x] 7.2 Implement `saveSetup` and `clearAll()`; make tests pass

## 8. BiometricAuthenticator Protocol

- [x] 8.1 Write failing tests: `BiometricAuthenticator` protocol compiles; mock satisfies `canEvaluateBiometrics()` and `authenticate()` (`AuthFlowProtocolTests/BiometricAuthenticatorTests.swift`)
- [x] 8.2 Add `BiometricAuthenticator` protocol and `BiometricAuthResult` to `AuthFlowProtocol`; make tests pass

## 9. LocalAuthentication BiometricAuthenticator

- [x] 9.1 Write failing tests: `LocalAuthenticationBiometricAuthenticator` wraps `LAContext` behind injectable seam (`AuthFlowUITests/LocalAuthenticationBiometricAuthenticatorTests.swift`)
- [x] 9.2 Implement `LocalAuthenticationBiometricAuthenticator` in `AuthFlowUI`; make tests pass

## 10. UnlockViewModel Protocol

- [x] 10.1 Write failing tests: `UnlockViewModel` protocol compiles; mock satisfies contract with locked initial state (`AuthFlowProtocolTests/UnlockViewModelTests.swift`)
- [x] 10.2 Add `UnlockViewModel` protocol and `UnlockFormState` to `AuthFlowProtocol`; make tests pass

## 11. DefaultUnlockViewModel — Bio-First Unlock

- [x] 11.1 Write failing tests: when `bioEnabled`, `unlock()` triggers biometric auth first; on success retrieves password and proceeds; on failure shows password form (`AuthFlowProtocolTests/DefaultUnlockViewModelBioTests.swift` — scenarios: Bio prompt on locked screen, Successful bio unlock proceeds to vault unlock, Failed bio shows password screen, Bio disabled shows password screen directly)
- [x] 11.2 Implement bio-first path in `DefaultUnlockViewModel`; make tests pass

## 12. DefaultUnlockViewModel — Online Session Restore

- [x] 12.1 Write failing tests: after presence check when online, calls `refreshSession()`; on success proceeds to vault unlock; on failure shows soft error (`AuthFlowProtocolTests/DefaultUnlockViewModelRefreshTests.swift` — scenarios: Successful refresh restores in-memory session, Failed refresh shows soft error, Refresh retried with entered password on soft failure, Offline skips refresh)
- [x] 12.2 Implement online refresh orchestration in `DefaultUnlockViewModel`; make tests pass

## 13. DefaultUnlockViewModel — Vault Unlock

- [x] 13.1 Write failing tests: reads header from `CredentialStore`, calls `VaultAuthenticator.unlockVault`, calls `vaultSession.establish()`; works offline with cached header (`AuthFlowProtocolTests/DefaultUnlockViewModelVaultTests.swift` — scenarios: Refresh success still requires password for vault, Offline unlock with cached header, Stale password allowed offline)
- [x] 13.2 Implement vault unlock path in `DefaultUnlockViewModel`; make tests pass

## 14. BiometricEnrollmentViewModel

- [x] 14.1 Write failing tests: `enableBiometrics(password:)` saves bio-gated password and sets flag; `skip()` leaves bio disabled (`AuthFlowProtocolTests/BiometricEnrollmentViewModelTests.swift` — scenarios: User can skip enrollment, Enable bio from Settings with password confirmation)
- [x] 14.2 Implement `DefaultBiometricEnrollmentViewModel`; make tests pass

## 15. Settings Biometrics Toggle

- [x] 15.1 Write failing tests: enabling requires password confirmation; disabling removes bio Keychain item (`AuthFlowProtocolTests/BiometricSettingsViewModelTests.swift` — scenario: Disable bio from Settings)
- [x] 15.2 Implement `DefaultBiometricSettingsViewModel`; make tests pass

## 16. Login/Register Setup Persistence

- [x] 16.1 Write failing tests: successful login calls `credentialStore.saveSetup` with email, refresh token, and vault header (`AuthFlowProtocolTests/DefaultLoginViewModelPersistenceTests.swift` — scenario: Save setup marks device ready)
- [x] 16.2 Update `DefaultLoginViewModel` to persist credentials after success; make tests pass
- [x] 16.3 Write failing tests: successful register calls `credentialStore.saveSetup` (`AuthFlowProtocolTests/DefaultRegisterViewModelPersistenceTests.swift`)
- [x] 16.4 Update `DefaultRegisterViewModel` to persist credentials after success; make tests pass

## 17. First-Launch Internet Gate

- [x] 17.1 Write failing tests: login/register blocked when offline and `!hasLocalSetup`; unlock allowed offline when `hasLocalSetup` (`AuthFlowProtocolTests/NetworkRequiredTests.swift` — scenarios: Offline blocks first login, Offline blocks first register, Offline does not block unlock)
- [x] 17.2 Add `NetworkReachability` protocol and inject into login/register ViewModels; implement `NWPathMonitor` adapter in app target; make tests pass

## 18. Auth Session Restore on Unlock

- [x] 18.1 Write failing tests: `PersistedAuthRepository` or unlock helper loads refresh token from `CredentialStore` and calls `refreshSession()`; lock clears memory only (`AuthRepositoryTests/SessionRestoreTests.swift` — scenarios: Lock clears in-memory auth tokens, Lock preserves Keychain credentials, Successful refresh restores in-memory session)
- [x] 18.2 Implement session restore helper; wire into unlock flow; make tests pass

## 19. Logout Full Reset

- [x] 19.1 Write failing tests: logout calls `credentialStore.clearAll()`, `vaultSession.clear()`, clears auth memory (`AuthFlowProtocolTests/LogoutResetTests.swift` — scenarios: Logout wipes all persisted state, Logout returns to first-launch login)
- [x] 19.2 Update `DefaultNoteListViewModel` logout to full reset; make tests pass

## 20. LockCoordinator

- [ ] 20.1 Write failing tests: lock on `scenePhase .background`, on `protectedDataWillBecomeUnavailable`, clears vault session and auth memory, no Keychain changes (`superSecureNotesTests/LockCoordinatorTests.swift` — scenarios: Lock on background, Lock on device lock screen, Locked on foreground return, No grace period, Lock clears vault session, Lock preserves Keychain credentials)
- [ ] 20.2 Implement `LockCoordinator` in app target; make tests pass

## 21. Root Navigation — Three States

- [ ] 21.1 Write failing tests: `SessionRootNavigation` routes to login when `!hasLocalSetup`, unlock when setup but inactive vault, notes when active (`superSecureNotesTests/SessionRootNavigationTests.swift` — scenarios: Returning user sees unlock not login, First launch sees login)
- [ ] 21.2 Update `SessionRootNavigation` and `RootView` for three-state routing; make tests pass

## 22. UnlockView UI

- [ ] 22.1 Write failing tests: `UnlockView` is publicly constructible; displays read-only email (`AuthFlowUITests/UnlockViewTests.swift` — scenarios: Email is read-only on unlock, Unlock strings are localized)
- [ ] 22.2 Implement `UnlockView` with password field, bio trigger, and error display; add `unlock.*` and `bio.*` localization keys; make tests pass

## 23. Biometric Enrollment UI

- [ ] 23.1 Write failing tests: enrollment sheet shown after first setup; not shown on subsequent unlocks (`AuthFlowUITests/BiometricEnrollmentViewTests.swift` — scenarios: Enrollment shown after first login, Enrollment not shown on subsequent unlocks)
- [ ] 23.2 Implement `BiometricEnrollmentView` sheet; wire after login/register success; make tests pass

## 24. Settings Biometrics Toggle UI

- [ ] 24.1 Write failing tests: Settings toggle wires to `BiometricSettingsViewModel` (`AuthFlowUITests/BiometricSettingsViewTests.swift`)
- [ ] 24.2 Add biometrics toggle to Settings screen; make tests pass

## 25. App Composition Wiring

- [ ] 25.1 Wire `KeychainCredentialStore`, `LockCoordinator`, `DefaultUnlockViewModel`, and `LocalAuthenticationBiometricAuthenticator` in `AppDependencies`
- [ ] 25.2 Update `RootView` to observe `hasLocalSetup` and locked state alongside `vaultSession.changes`
- [ ] 25.3 Build and run app; confirm unlock screen appears after backgrounding

## 26. Verification

- [ ] 26.1 Run `swift test` in `Packages/AuthFlow`; confirm all tests pass
- [ ] 26.2 Run app target tests; confirm lock coordinator and navigation tests pass
- [ ] 26.3 Update `Packages/AuthFlow/README.md` with credential store, lock/unlock, and biometrics documentation
