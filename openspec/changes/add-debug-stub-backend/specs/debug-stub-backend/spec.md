## ADDED Requirements

### Requirement: DEBUG launch argument gate

The app target SHALL support a DEBUG-only launch argument `-UseStubBackend`. When this argument is present at launch, `AppDependencies` SHALL construct stub repository implementations instead of `NetworkAuthRepository` and `NetworkVaultRepository`. When the argument is absent, `AppDependencies` SHALL use the network implementations. This gate SHALL NOT exist in Release builds.

#### Scenario: Stub mode enabled via launch argument

- **WHEN** the app launches in DEBUG with `-UseStubBackend` in process arguments
- **THEN** `AppDependencies` provides stub auth and vault repository implementations

#### Scenario: Network mode without launch argument

- **WHEN** the app launches in DEBUG without `-UseStubBackend`
- **THEN** `AppDependencies` provides `NetworkAuthRepository` and `NetworkVaultRepository`

#### Scenario: Release builds always use network repositories

- **WHEN** the app is built in Release configuration
- **THEN** stub repository types are not compiled and network repositories are always used

### Requirement: InMemoryAuthRepository

The app target SHALL provide a DEBUG-only `InMemoryAuthRepository` actor conforming to `AuthRepository`. It SHALL accept any non-empty credentials for `register` and `login`, returning a valid `AuthSession` and storing a `User` derived from the email. It SHALL clear session state on `logout` without making network calls. It SHALL throw `AuthRepositoryError.notAuthenticated` from `refreshSession` when no session exists.

#### Scenario: Register stores session

- **WHEN** `register` is called with valid credentials
- **THEN** a non-nil `AuthSession` is returned and `currentSession` reflects it

#### Scenario: Login stores session

- **WHEN** `login` is called with valid credentials
- **THEN** a non-nil `AuthSession` is returned and `currentUser` reflects the email

#### Scenario: Logout clears state

- **WHEN** `logout` is called after a successful login
- **THEN** `currentSession` and `currentUser` are nil

### Requirement: FileVaultRepository

The app target SHALL provide a DEBUG-only `FileVaultRepository` actor conforming to `VaultRepository`. It SHALL persist vault header bytes to a file in the app sandbox Application Support directory. `writeHeader(_:)` SHALL create the storage directory if needed and write the header bytes. `readHeader()` SHALL return the persisted bytes or throw `VaultRepositoryError.headerNotFound` if no file exists. `fetchPublicKey(userID:)` SHALL return 32 bytes without requiring network access.

#### Scenario: Write then read header roundtrip

- **WHEN** `writeHeader` is called with header bytes and then `readHeader` is called
- **THEN** the returned data equals the written bytes

#### Scenario: Read header when file missing

- **WHEN** `readHeader` is called and no header file exists
- **THEN** `VaultRepositoryError.headerNotFound` is thrown

#### Scenario: Header survives process restart

- **WHEN** `writeHeader` is called, the app process terminates, and a new process calls `readHeader`
- **THEN** the returned data equals the previously written bytes

### Requirement: Stub mode uses real crypto and vault session

When stub backend is enabled, `AppDependencies` SHALL still construct `SecureCryptoVaultAuthenticator` and `VaultSession` (not preview or mock implementations).

#### Scenario: Register uses real vault creation

- **WHEN** stub mode is enabled and the user completes registration
- **THEN** `SecureCryptoVaultAuthenticator.createVault` produces a valid vault header stored by `FileVaultRepository`

#### Scenario: Login uses real vault unlock

- **WHEN** stub mode is enabled and the user logs in with the correct password
- **THEN** `SecureCryptoVaultAuthenticator.unlockVault` succeeds against the persisted header

#### Scenario: Vault session emits changes on establish

- **WHEN** stub mode is enabled and login or register completes successfully
- **THEN** `VaultSession.isActive` becomes true and `changes` emits `true`
