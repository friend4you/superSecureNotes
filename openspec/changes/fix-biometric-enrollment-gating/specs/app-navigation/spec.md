## ADDED Requirements

### Requirement: Root navigation gated on pending biometric enrollment

`SessionRootNavigation.apply` SHALL accept pending enrollment state and SHALL NOT call `setRoot(NotesRoute.list)` while `pendingBiometricEnrollment` is `true`, even when `isVaultActive` is `true`.

#### Scenario: Active vault with pending enrollment stays on auth root

- **WHEN** `SessionRootNavigation.apply` is called with `isVaultActive == true`, `hasLocalSetup == true`, and `pendingBiometricEnrollment == true`
- **THEN** the root route is not changed to `NotesRoute.list`

#### Scenario: Active vault without pending enrollment navigates to notes

- **WHEN** `SessionRootNavigation.apply` is called with `isVaultActive == true`, `hasLocalSetup == true`, and `pendingBiometricEnrollment == false`
- **THEN** `navigator.setRoot(NotesRoute.list)` is called

#### Scenario: RootView sync passes pending enrollment state

- **WHEN** `RootView` syncs root route on vault session changes
- **THEN** it passes the current `pendingBiometricEnrollment` value to `SessionRootNavigation.apply`
