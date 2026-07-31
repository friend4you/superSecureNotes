## MODIFIED Requirements

### Requirement: Lock clears in-memory session only

On lock, the system SHALL call `noteRepository.closeDatabase()`, then `vaultSession.clear()`, and clear in-memory auth session state (`currentSession`, `currentUser`). The system SHALL NOT modify Keychain contents on lock.

#### Scenario: Lock closes note database

- **WHEN** a lock event occurs while the note database is open
- **THEN** `noteRepository.closeDatabase()` is called before `vaultSession.clear()`

#### Scenario: Lock clears vault session

- **WHEN** a lock event occurs while `vaultSession.isActive` is `true`
- **THEN** `vaultSession.isActive` becomes `false`

#### Scenario: Lock clears in-memory auth tokens

- **WHEN** a lock event occurs while `authRepository.currentSession` is non-nil
- **THEN** `authRepository.currentSession` becomes `nil`

#### Scenario: Lock preserves Keychain credentials

- **WHEN** a lock event occurs after device setup
- **THEN** `credentialStore.hasLocalSetup` remains `true` and `credentialStore.email()` is unchanged

### Requirement: Logout full reset

Logout SHALL call `noteRepository.closeDatabase()`, `credentialStore.clearAll()`, `vaultSession.clear()`, clear in-memory auth state, and navigate to the login screen with editable email.

#### Scenario: Logout closes note database

- **WHEN** the user taps logout
- **THEN** `noteRepository.closeDatabase()` is called before `vaultSession.clear()`

#### Scenario: Logout wipes all persisted credentials

- **WHEN** the user taps logout
- **THEN** `hasLocalSetup` is `false` and all Keychain items are removed

#### Scenario: Logout returns to first-launch login

- **WHEN** logout completes
- **THEN** the login screen is shown with an editable email field

#### Scenario: Account switch requires logout

- **WHEN** a user wants to sign in with a different email
- **THEN** they must logout first; there is no in-app account switch without full reset
