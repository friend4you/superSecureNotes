## Why

After first-time login or register, the biometric enrollment sheet races with `SessionRootNavigation.setRoot(NotesRoute.list)`. `NavigationRouter.setRoot` clears any presented sheet, so enrollment is flaky — sometimes it never appears. Separately, enabling biometrics from Settings and the enrollment prompt both re-ask for a password the user already entered during login/register/unlock, even though the vault is already unlocked.

## What Changes

- Add **in-memory session password cache** populated on login, register, and unlock; cleared on lock and logout
- Add **`pendingBiometricEnrollment` flag in UserDefaults** set on first setup; cleared when user skips or enables biometrics
- **Gate navigation to notes** while `pendingBiometricEnrollment` is true — stay on login/register under the enrollment sheet; navigate to notes only after enrollment completes
- **Resume pending enrollment after unlock** if the app was backgrounded or killed mid-prompt
- **Remove password field** from first-setup enrollment when session cache has the password
- **Enable biometrics from Settings without password re-entry** when session cache has the password; fall back to password confirmation when cache is empty (e.g. after cold unlock without re-cache)
- Add integration tests covering enrollment survival across `setRoot` and settings enable via cache

## Capabilities

### New Capabilities

- `session-password-cache`: In-memory vault password cache for the active unlocked session; populated by auth use cases; cleared on lock/logout
- `biometric-enrollment-gating`: UserDefaults-backed pending enrollment flag and root-navigation gating until enrollment is dismissed

### Modified Capabilities

- `biometric-unlock`: Settings enable uses session cache instead of mandatory password field; enrollment omits password field when cache is available; pending enrollment resumes after unlock when flag is set
- `app-navigation`: `SessionRootNavigation` SHALL NOT navigate to notes while `pendingBiometricEnrollment` is true
- `session-lock`: Lock and logout SHALL clear the session password cache (not the UserDefaults pending flag until enrollment completes)

## Impact

- `Packages/AuthFlow/Sources/AuthFlowProtocol/` — new `SessionPasswordCache`; updated biometric settings/enrollment view models; login/register pass password to enrollment
- `Packages/AuthFlow/Sources/AuthFlowDomain/` — login, register, unlock use cases store password in cache after successful vault establishment
- `Packages/AuthFlow/Sources/AuthFlowUI/` — simplified `BiometricEnrollmentView` (no password field when cache available); simplified `BiometricSettingsView`
- `superSecureNotes/SessionRootNavigation.swift` — gate `setRoot(notes)` on pending enrollment flag
- `superSecureNotes/RootView.swift` — observe pending enrollment flag for root sync
- `superSecureNotes/AppComposition.swift` — wire cache, pending flag store, lock/logout clearing
- `Packages/AuthFlow/Tests/` and `superSecureNotesTests/` — new and updated tests per TDD policy
