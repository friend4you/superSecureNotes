## ADDED Requirements

### Requirement: Biometric enrollment offer after first setup

After the first successful login or register that completes device setup, the app SHALL present a one-time biometric enrollment prompt with enable and skip options.

#### Scenario: Enrollment shown after first login

- **WHEN** login succeeds and `hasLocalSetup` transitions from `false` to `true`
- **THEN** a biometric enrollment prompt is displayed

#### Scenario: Enrollment shown after first register

- **WHEN** register succeeds and `hasLocalSetup` transitions from `false` to `true`
- **THEN** a biometric enrollment prompt is displayed

#### Scenario: User can skip enrollment

- **WHEN** the user chooses "Not Now" on the enrollment prompt
- **THEN** `bioEnabled` remains `false` and the app proceeds to notes

#### Scenario: Enrollment not shown on subsequent unlocks

- **WHEN** the user returns to the app after skipping enrollment
- **THEN** the enrollment prompt is not shown again automatically

### Requirement: Enable biometrics from Settings

The app SHALL provide a Settings toggle to enable or disable biometric unlock. Enabling SHALL require the user to enter their password once. Disabling SHALL remove the bio-gated password Keychain item.

#### Scenario: Enable bio from Settings with password confirmation

- **WHEN** the user enables the biometric toggle in Settings and confirms their password
- **THEN** `bioEnabled` is `true` and the password is stored in a bio-gated Keychain item

#### Scenario: Disable bio from Settings

- **WHEN** the user disables the biometric toggle in Settings
- **THEN** `bioEnabled` is `false` and the bio-gated password item is removed

### Requirement: Bio-first unlock

When `bioEnabled` is `true` and the app is in locked state, the unlock screen SHALL attempt biometric authentication immediately before showing the password field.

#### Scenario: Bio prompt on locked screen

- **WHEN** the unlock screen appears and `bioEnabled` is `true`
- **THEN** a biometric authentication prompt is presented automatically

#### Scenario: Successful bio unlock proceeds to vault unlock

- **WHEN** biometric authentication succeeds and password is retrieved from Keychain
- **THEN** the unlock flow continues with the retrieved password without showing the password field

#### Scenario: Failed bio shows password screen

- **WHEN** biometric authentication fails or is cancelled
- **THEN** the password entry screen is shown with email displayed read-only

#### Scenario: Bio disabled shows password screen directly

- **WHEN** `bioEnabled` is `false` and the unlock screen appears
- **THEN** the password entry screen is shown without a biometric prompt

#### Scenario: OS biometrics disabled falls back to password

- **WHEN** biometrics are unavailable at the OS level
- **THEN** the password entry screen is shown with email read-only

### Requirement: Password-only unlock UI

The unlock screen SHALL display the persisted email as read-only. The user SHALL enter only their password. The email field SHALL NOT be editable during unlock.

#### Scenario: Email is read-only on unlock

- **WHEN** the password unlock screen is displayed
- **THEN** the email is visible and not editable

#### Scenario: Password submission triggers unlock

- **WHEN** the user enters their password and submits on the unlock screen
- **THEN** the unlock orchestration begins with the entered password

### Requirement: Online session restore after user presence

When the device is online during unlock, after the user provides presence (bio or password), the system SHALL attempt to restore the server session using the persisted refresh token before vault unlock.

#### Scenario: Successful refresh restores in-memory session

- **WHEN** the user completes presence check, the device is online, and `refreshSession()` succeeds
- **THEN** `authRepository.currentSession` is non-nil before vault unlock completes

#### Scenario: Failed refresh shows soft error

- **WHEN** the user completes presence check, the device is online, and `refreshSession()` fails
- **THEN** a session-expired error is shown and the user must re-enter their password

#### Scenario: Refresh retried with entered password on soft failure

- **WHEN** refresh fails and the user re-enters their password on the unlock screen
- **THEN** the system attempts server login with the stored email and entered password

#### Scenario: Offline skips refresh

- **WHEN** the device is offline during unlock
- **THEN** no refresh or login network call is made and vault unlock proceeds locally

### Requirement: Vault unlock always requires password

Regardless of refresh token success, vault unlock SHALL always use a password — retrieved via biometrics or entered by the user — to derive vault keys and call `vaultSession.establish()`.

#### Scenario: Refresh success still requires password for vault

- **WHEN** refresh succeeds during unlock
- **THEN** vault unlock still uses the password and `vaultSession.establish()` is called

#### Scenario: Offline unlock with cached header

- **WHEN** the device is offline and the user provides a password
- **THEN** vault header is read from `CredentialStore`, vault is unlocked locally, and `vaultSession.establish()` is called

#### Scenario: Stale password allowed offline

- **WHEN** the device is offline, the server password was changed elsewhere, and the locally stored password still unwraps the cached vault header
- **THEN** unlock succeeds without detecting the server-side password change

### Requirement: UnlockView localization

The unlock screen and biometric enrollment prompt SHALL use localized strings via `AuthFlowUI` string catalog.

#### Scenario: Unlock strings are localized

- **WHEN** `UnlockView` is displayed
- **THEN** all user-visible labels use `Localizable.xcstrings` keys under `unlock.*` and `bio.*` namespaces
