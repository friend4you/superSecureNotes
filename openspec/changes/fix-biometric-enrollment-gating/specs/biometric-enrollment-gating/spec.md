## ADDED Requirements

### Requirement: Pending biometric enrollment flag

The app SHALL persist a `pendingBiometricEnrollment` boolean in UserDefaults. The flag SHALL be set to `true` when first-time login or register completes device setup and biometric enrollment has not yet been dismissed. The flag SHALL be cleared when the user skips or successfully enables biometrics on the enrollment prompt.

#### Scenario: First setup sets pending flag

- **WHEN** login or register succeeds with `wasFirstSetup == true`
- **THEN** `pendingBiometricEnrollment` is `true` before the enrollment sheet is presented

#### Scenario: Skip clears pending flag

- **WHEN** the user taps skip on the biometric enrollment prompt
- **THEN** `pendingBiometricEnrollment` is `false`

#### Scenario: Enable clears pending flag

- **WHEN** the user successfully enables biometrics on the enrollment prompt
- **THEN** `pendingBiometricEnrollment` is `false`

#### Scenario: Pending flag survives app termination

- **WHEN** the app terminates while `pendingBiometricEnrollment` is `true`
- **THEN** the flag remains `true` on next launch

### Requirement: Notes root blocked while enrollment pending

While `pendingBiometricEnrollment` is `true`, the app SHALL NOT navigate to the notes root even if the vault session is active. The auth root (login or register) SHALL remain visible underneath the enrollment sheet until enrollment is dismissed.

#### Scenario: Vault active does not navigate to notes while pending

- **WHEN** vault session becomes active and `pendingBiometricEnrollment` is `true`
- **THEN** `SessionRootNavigation` does not call `setRoot(NotesRoute.list)`

#### Scenario: Notes navigation after enrollment dismissed

- **WHEN** the user skips or enables biometrics and `pendingBiometricEnrollment` becomes `false` while the vault session is active
- **THEN** the app navigates to the notes root

#### Scenario: setRoot does not dismiss enrollment sheet

- **WHEN** vault session becomes active during pending enrollment
- **THEN** the enrollment sheet remains presented until the user skips or enables biometrics

### Requirement: Pending enrollment resumes after unlock

When `pendingBiometricEnrollment` is `true` and the user unlocks the vault, the app SHALL present the biometric enrollment prompt before navigating to notes.

#### Scenario: Enrollment shown after unlock when pending

- **WHEN** unlock succeeds and `pendingBiometricEnrollment` is `true`
- **THEN** the biometric enrollment prompt is presented before notes navigation

#### Scenario: No enrollment after unlock when not pending

- **WHEN** unlock succeeds and `pendingBiometricEnrollment` is `false`
- **THEN** the enrollment prompt is not presented automatically

#### Scenario: Lock during enrollment resumes on next unlock

- **WHEN** the user backgrounds the app during pending enrollment, the vault locks, and the user unlocks again
- **THEN** the enrollment prompt is presented again before notes navigation
