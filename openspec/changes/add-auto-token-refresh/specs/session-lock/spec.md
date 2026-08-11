## ADDED Requirements

### Requirement: Forced logout on dead refresh token

When the refresh token is expired or revoked during an unlocked session, the system SHALL perform the same full reset as user-initiated logout: close notes index store, wipe Keychain via `credentialStore.clearAll()`, clear vault session, clear in-memory auth state, and navigate to login. This SHALL NOT be implemented as a lock (Keychain must be wiped, not preserved).

#### Scenario: Forced logout wipes Keychain

- **WHEN** session expiry logout is triggered mid-session
- **THEN** `credentialStore.hasLocalSetup` is `false` and `credentialStore.refreshToken()` is `nil`

#### Scenario: Forced logout differs from lock

- **WHEN** session expiry logout is triggered mid-session
- **THEN** Keychain credentials are removed, unlike a lock event which preserves them

#### Scenario: Lock after session expiry logout is not applicable

- **WHEN** session expiry logout completes
- **THEN** the app is on the login screen, not the unlock screen
