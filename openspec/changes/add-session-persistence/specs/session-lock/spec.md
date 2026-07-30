## ADDED Requirements

### Requirement: Lock clears in-memory session only

On lock, the system SHALL call `vaultSession.clear()` and clear in-memory auth session state (`currentSession`, `currentUser`). The system SHALL NOT modify Keychain contents on lock.

#### Scenario: Lock clears vault session

- **WHEN** a lock event occurs while `vaultSession.isActive` is `true`
- **THEN** `vaultSession.isActive` becomes `false`

#### Scenario: Lock clears in-memory auth tokens

- **WHEN** a lock event occurs while `authRepository.currentSession` is non-nil
- **THEN** `authRepository.currentSession` becomes `nil`

#### Scenario: Lock preserves Keychain credentials

- **WHEN** a lock event occurs after device setup
- **THEN** `credentialStore.hasLocalSetup` remains `true` and `credentialStore.email()` is unchanged

### Requirement: Lock triggers

The app SHALL lock immediately with no grace period when any of the following occur: app enters background (`scenePhase == .background`), device lock screen activates (`UIApplication.protectedDataWillBecomeUnavailable`), or app returns to foreground while previously locked.

#### Scenario: Lock on background

- **WHEN** the app `scenePhase` transitions to `.background`
- **THEN** the app enters locked state

#### Scenario: Lock on device lock screen

- **WHEN** `protectedDataWillBecomeUnavailable` notification fires
- **THEN** the app enters locked state

#### Scenario: Locked on foreground return

- **WHEN** the app returns to foreground after being backgrounded
- **THEN** the user sees the unlock screen before accessing notes

#### Scenario: No grace period

- **WHEN** the app backgrounds for less than one second
- **THEN** the app still locks immediately

### Requirement: Locked navigation state

When `hasLocalSetup` is `true` and `vaultSession.isActive` is `false`, the app root SHALL show the unlock screen, not the login/register screen.

#### Scenario: Returning user sees unlock not login

- **WHEN** the app launches with `hasLocalSetup == true` and inactive vault session
- **THEN** the unlock screen is displayed with email shown read-only

#### Scenario: First launch sees login

- **WHEN** the app launches with `hasLocalSetup == false`
- **THEN** the login screen is displayed with editable email

### Requirement: First launch requires internet

When `hasLocalSetup` is `false`, login and register submission SHALL be blocked if the device has no network connectivity, with a localized error message.

#### Scenario: Offline blocks first login

- **WHEN** `hasLocalSetup` is `false` and the device is offline and the user submits login
- **THEN** login does not proceed and a network-required error is shown

#### Scenario: Offline blocks first register

- **WHEN** `hasLocalSetup` is `false` and the device is offline and the user submits register
- **THEN** register does not proceed and a network-required error is shown

#### Scenario: Offline does not block unlock

- **WHEN** `hasLocalSetup` is `true` and the device is offline and the user unlocks with password
- **THEN** unlock proceeds using cached vault header without server calls

### Requirement: Logout full reset

Logout SHALL call `credentialStore.clearAll()`, `vaultSession.clear()`, clear in-memory auth state, and navigate to the login screen with editable email.

#### Scenario: Logout wipes all persisted state

- **WHEN** the user taps logout
- **THEN** `hasLocalSetup` is `false` and all Keychain items are removed

#### Scenario: Logout returns to first-launch login

- **WHEN** logout completes
- **THEN** the login screen is shown with an editable email field

#### Scenario: Account switch requires logout

- **WHEN** a user wants to sign in with a different email
- **THEN** they must logout first; there is no in-app account switch without full reset
