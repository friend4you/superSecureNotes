## ADDED Requirements

### Requirement: Session password cache stores unlock password in memory

The app SHALL maintain an in-memory session password cache holding the vault plaintext password for the duration of an active unlocked session. The cache SHALL NOT persist the password to UserDefaults, files, or Keychain except when the user explicitly enables biometric unlock.

#### Scenario: Login populates session cache

- **WHEN** login succeeds and vault session is established
- **THEN** the session password cache contains the password used for vault unlock

#### Scenario: Register populates session cache

- **WHEN** registration succeeds and vault session is established
- **THEN** the session password cache contains the password used for vault unlock

#### Scenario: Unlock populates session cache

- **WHEN** unlock with password succeeds and vault session is established
- **THEN** the session password cache contains the password used for vault unlock

#### Scenario: Cache is empty when vault is locked

- **WHEN** the vault session is not active and no unlock is in progress
- **THEN** the session password cache returns no password

### Requirement: Session password cache cleared on lock and logout

The session password cache SHALL be cleared when the vault locks or the user logs out. Clearing SHALL NOT modify Keychain credentials or the pending biometric enrollment flag.

#### Scenario: Lock clears session cache

- **WHEN** a lock event occurs
- **THEN** the session password cache is cleared

#### Scenario: Logout clears session cache

- **WHEN** logout completes
- **THEN** the session password cache is cleared

#### Scenario: Lock does not clear pending enrollment flag

- **WHEN** a lock event occurs while `pendingBiometricEnrollment` is `true`
- **THEN** the pending enrollment flag remains `true`
