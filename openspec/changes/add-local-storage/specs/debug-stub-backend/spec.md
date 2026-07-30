## MODIFIED Requirements

### Requirement: DEBUG launch argument gate

The app target SHALL support a DEBUG-only launch argument `-UseStubBackend`. When this argument is present at launch, `AppDependencies` SHALL construct `InMemoryAuthRepository` instead of `NetworkAuthRepository`. When the argument is absent, `AppDependencies` SHALL use `NetworkAuthRepository`. Note and vault repositories SHALL always use `LocalNoteRepository` and `LocalVaultRepository` regardless of stub configuration. This gate SHALL NOT exist in Release builds.

#### Scenario: Stub mode enabled via launch argument

- **WHEN** the app launches in DEBUG with `-UseStubBackend` in process arguments
- **THEN** `AppDependencies` provides `InMemoryAuthRepository` and local note and vault repositories

#### Scenario: Network auth mode without launch argument

- **WHEN** the app launches in DEBUG without `-UseStubBackend`
- **THEN** `AppDependencies` provides `NetworkAuthRepository` and local note and vault repositories

#### Scenario: Release builds use network auth with local storage

- **WHEN** the app is built in Release configuration
- **THEN** `InMemoryAuthRepository` is not compiled and `NetworkAuthRepository` is used with local note and vault repositories

### Requirement: Stub mode uses real crypto and vault session

When stub backend is enabled, `AppDependencies` SHALL still construct `SecureCryptoVaultAuthenticator` and `VaultSession` (not preview or mock implementations).

#### Scenario: Register uses real vault creation

- **WHEN** stub mode is enabled and the user completes registration
- **THEN** `SecureCryptoVaultAuthenticator.createVault` produces a valid vault header stored by `LocalVaultRepository`

#### Scenario: Login uses real vault unlock

- **WHEN** stub mode is enabled and the user logs in with the correct password
- **THEN** `SecureCryptoVaultAuthenticator.unlockVault` succeeds against the persisted header

#### Scenario: Vault session emits changes on establish

- **WHEN** stub mode is enabled and login or register completes successfully
- **THEN** `VaultSession.isActive` becomes true and `changes` emits `true`

## REMOVED Requirements

### Requirement: FileVaultRepository

**Reason**: Replaced by `LocalVaultRepository` in the `VaultRepository` package with Application Support path and iCloud backup exclusion.

**Migration**: No automatic migration; wipe app data. New path: `Application Support/superSecureNotes/vault/vault-header.bin`.
