## ADDED Requirements

### Requirement: CredentialStore package module boundary

The project SHALL provide `CredentialStoreProtocol` and `CredentialStore` library products inside the `AuthFlow` package. `CredentialStoreProtocol` SHALL depend on Foundation only. `CredentialStore` SHALL implement Keychain persistence using Security framework APIs.

#### Scenario: Package builds with protocol and implementation targets

- **WHEN** the `AuthFlow` package is built with `CredentialStore` targets
- **THEN** both `CredentialStoreProtocol` and `CredentialStore` targets compile successfully

#### Scenario: Protocol module has no Security framework dependency

- **WHEN** `CredentialStoreProtocol` is built
- **THEN** it does not import Security or Keychain APIs

### Requirement: Device setup flag

The store SHALL persist a `hasLocalSetup` boolean indicating the device has completed first-time authentication. `hasLocalSetup` SHALL be `false` when no setup data exists.

#### Scenario: Initial state is not set up

- **WHEN** a fresh `CredentialStore` is queried for `hasLocalSetup`
- **THEN** the value is `false`

#### Scenario: Mark device set up after first auth

- **WHEN** `markSetupComplete()` is called after successful first login or register
- **THEN** subsequent reads of `hasLocalSetup` return `true`

### Requirement: Email persistence

The store SHALL persist the authenticated user's email address. Email SHALL remain stored across lock/unlock cycles and SHALL be cleared only by `clearAll()`.

#### Scenario: Save and read email

- **WHEN** `saveEmail(_:)` is called with a valid email string
- **THEN** `email()` returns the same string

#### Scenario: Email cleared on full reset

- **WHEN** `clearAll()` is called after email was saved
- **THEN** `email()` returns `nil`

### Requirement: Refresh token persistence

The store SHALL persist the server refresh token. The refresh token SHALL survive lock/unlock and SHALL be cleared only by `clearAll()`.

#### Scenario: Save and read refresh token

- **WHEN** `saveRefreshToken(_:)` is called
- **THEN** `refreshToken()` returns the same token string

#### Scenario: Refresh token cleared on full reset

- **WHEN** `clearAll()` is called after a refresh token was saved
- **THEN** `refreshToken()` returns `nil`

### Requirement: Vault header cache

The store SHALL persist the vault header as opaque `Data`. The cached header SHALL be written after first successful login or register and SHALL be read during unlock without network access.

#### Scenario: Save and read vault header

- **WHEN** `saveVaultHeader(_:)` is called with header bytes
- **THEN** `vaultHeader()` returns the same `Data`

#### Scenario: Vault header updated on successful online unlock

- **WHEN** a new vault header is fetched from the server during unlock and `saveVaultHeader(_:)` is called
- **THEN** subsequent `vaultHeader()` reads return the updated bytes

#### Scenario: Vault header cleared on full reset

- **WHEN** `clearAll()` is called
- **THEN** `vaultHeader()` returns `nil`

### Requirement: Bio-gated password storage

When biometrics are enabled, the store SHALL persist the user's password in a Keychain item protected by `kSecAccessControlBiometryCurrentSet` and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. When biometrics are disabled, the password item SHALL NOT exist.

#### Scenario: Save password with biometrics enabled

- **WHEN** `savePassword(_:)` is called while `bioEnabled` is `true`
- **THEN** `loadPasswordWithBiometrics()` can retrieve the same password after successful biometric authentication

#### Scenario: Password item removed when biometrics disabled

- **WHEN** `setBioEnabled(false)` is called
- **THEN** `loadPasswordWithBiometrics()` fails and no password item exists in Keychain

#### Scenario: Password not stored when biometrics never enabled

- **WHEN** `bioEnabled` is `false` and no `savePassword` was called
- **THEN** `loadPasswordWithBiometrics()` fails

### Requirement: Biometrics enabled flag

The store SHALL persist a `bioEnabled` boolean preference independent of whether a password Keychain item currently exists.

#### Scenario: Bio flag defaults to false

- **WHEN** a fresh `CredentialStore` is queried for `bioEnabled`
- **THEN** the value is `false`

#### Scenario: Bio flag updated on enable

- **WHEN** `setBioEnabled(true)` is called after password is saved
- **THEN** `bioEnabled()` returns `true`

### Requirement: Full reset on logout

The store SHALL provide `clearAll()` that removes all persisted items: email, refresh token, password, vault header, `bioEnabled`, and `hasLocalSetup`.

#### Scenario: Clear all removes every item

- **WHEN** `clearAll()` is called after a complete setup
- **THEN** `hasLocalSetup`, `email()`, `refreshToken()`, `vaultHeader()`, `bioEnabled()`, and password retrieval all return empty/false/nil

### Requirement: Complete setup persistence

The store SHALL provide `saveSetup(email:refreshToken:vaultHeader:)` that atomically persists email, refresh token, vault header, and sets `hasLocalSetup` to `true`.

#### Scenario: Save setup marks device ready

- **WHEN** `saveSetup(email:refreshToken:vaultHeader:)` is called
- **THEN** `hasLocalSetup` is `true`, email, refresh token, and vault header are readable
