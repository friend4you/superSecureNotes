## ADDED Requirements

### Requirement: Account deletion full reset

Account deletion SHALL perform a server-side hard delete via `AuthRepository.deleteAccount(password:)`, then the same local reset as logout: `notesIndexStore.close()`, `credentialStore.clearAll()`, local app data wipe, `vaultSession.clear()`, and navigation to the login screen with editable email. Account deletion SHALL NOT be reachable without password confirmation.

#### Scenario: Delete closes notes index store

- **WHEN** account deletion succeeds
- **THEN** `notesIndexStore.close()` is called before `vaultSession.clear()`

#### Scenario: Delete wipes all persisted credentials

- **WHEN** account deletion succeeds
- **THEN** `hasLocalSetup` is `false` and all Keychain items are removed

#### Scenario: Delete returns to first-launch login

- **WHEN** account deletion completes successfully
- **THEN** the login screen is shown with an editable email field

#### Scenario: Delete is distinct from logout

- **WHEN** the user chooses logout
- **THEN** the server account is not deleted; only local session and credentials are cleared via the existing logout API

#### Scenario: Delete requires server success before local wipe

- **WHEN** the delete-account API call fails
- **THEN** local credentials and note data are not wiped
