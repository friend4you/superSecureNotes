## MODIFIED Requirements

### Requirement: Biometric enrollment offer after first setup

After the first successful login or register that completes device setup, the app SHALL present a one-time biometric enrollment prompt with enable and skip options. The enrollment prompt SHALL remain visible until dismissed even if the vault session becomes active. Navigation to notes SHALL occur only after the user skips or enables biometrics.

#### Scenario: Enrollment shown after first login

- **WHEN** login succeeds and `hasLocalSetup` transitions from `false` to `true`
- **THEN** a biometric enrollment prompt is displayed and notes navigation is deferred until dismissal

#### Scenario: Enrollment shown after first register

- **WHEN** register succeeds and `hasLocalSetup` transitions from `false` to `true`
- **THEN** a biometric enrollment prompt is displayed and notes navigation is deferred until dismissal

#### Scenario: User can skip enrollment

- **WHEN** the user chooses "Not Now" on the enrollment prompt
- **THEN** `bioEnabled` remains `false`, `pendingBiometricEnrollment` is cleared, and the app navigates to notes

#### Scenario: Enrollment not shown after explicit skip

- **WHEN** the user previously skipped enrollment and `pendingBiometricEnrollment` is `false`
- **THEN** the enrollment prompt is not shown automatically on subsequent unlocks or logins

#### Scenario: Enrollment uses session password without re-prompt

- **WHEN** the user taps enable on the enrollment prompt and the session password cache contains the login or register password
- **THEN** biometrics are enabled without displaying a password entry field

### Requirement: Enable biometrics from Settings

The app SHALL provide a Settings toggle to enable or disable biometric unlock. When the session password cache contains the vault password, enabling SHALL use the cached password without requiring user re-entry. When the cache is empty, enabling SHALL require the user to enter their password once. Disabling SHALL remove the bio-gated password Keychain item.

#### Scenario: Enable bio from Settings using session cache

- **WHEN** the user enables the biometric toggle in Settings and the session password cache contains the vault password
- **THEN** `bioEnabled` is `true`, the password is stored in a bio-gated Keychain item, and no password field is shown

#### Scenario: Enable bio from Settings with password fallback

- **WHEN** the user enables the biometric toggle in Settings and the session password cache is empty
- **THEN** the app prompts for password confirmation before enabling biometrics

#### Scenario: Disable bio from Settings

- **WHEN** the user disables the biometric toggle in Settings
- **THEN** `bioEnabled` is `false` and the bio-gated password item is removed

## ADDED Requirements

### Requirement: Biometric enrollment enable without password field on first setup

The biometric enrollment screen SHALL NOT display a password entry field when the session password cache contains the vault password from the preceding login or register flow.

#### Scenario: Enrollment view omits password field on first setup

- **WHEN** the enrollment prompt is presented immediately after first-time login or register
- **THEN** no password SecureField is displayed

#### Scenario: Enable button stores cached password

- **WHEN** the user taps enable on the enrollment prompt with a populated session cache
- **THEN** `bioEnabled` is set to `true` and the cached password is stored in the bio-gated Keychain item
