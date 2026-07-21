## ADDED Requirements

### Requirement: VaultSession package module boundary

The project SHALL provide a Swift Package `VaultSession` with two library products: `VaultSessionProtocol` (contracts and shared types) and `VaultSession` (default actor implementation). `VaultSessionProtocol` SHALL depend only on Foundation and CryptoKit. `VaultSession` SHALL depend on `VaultSessionProtocol`.

#### Scenario: Package builds with protocol and implementation targets

- **WHEN** the `VaultSession` package is built
- **THEN** both `VaultSessionProtocol` and `VaultSession` targets compile successfully

#### Scenario: Protocol module has no SecureCrypto dependency

- **WHEN** `VaultSessionProtocol` is built
- **THEN** it does not import or link `SecureCrypto` or `SecureCryptoProtocol`

### Requirement: VaultSessionKeys payload

The module SHALL define `VaultSessionKeys` as a `Sendable` value type containing a vault UDK (`SymmetricKey`) and an identity private key (`Data` of 32 bytes). Session storage SHALL hold only this payload while active.

#### Scenario: Keys struct carries UDK and identity private key

- **WHEN** a `VaultSessionKeys` value is created with a UDK and 32-byte identity private key
- **THEN** both values are accessible as stored properties

### Requirement: Session lifecycle establish and clear

The module SHALL provide a `VaultSession` protocol implemented by an `actor` with `establish(_ keys: VaultSessionKeys)` and `clear()` methods. `establish` SHALL store keys in memory and mark the session active. `clear` SHALL remove stored keys and mark the session inactive. Only the auth module SHALL call `establish` and `clear` by convention at the composition root.

#### Scenario: Establish makes session active

- **WHEN** `establish` is called with valid `VaultSessionKeys` on an inactive session
- **THEN** `isActive` is `true`

#### Scenario: Clear makes session inactive

- **WHEN** `clear` is called on an active session
- **THEN** `isActive` is `false`

#### Scenario: Clear when already inactive is idempotent

- **WHEN** `clear` is called on an inactive session
- **THEN** `isActive` remains `false` and no error is thrown

#### Scenario: Establish replaces keys when already active

- **WHEN** `establish` is called while the session is already active with different keys
- **THEN** subsequent key reads return the newly established keys and `isActive` remains `true`

#### Scenario: Initial state is inactive

- **WHEN** a new `VaultSession` actor is created
- **THEN** `isActive` is `false`

### Requirement: Key access when active

While the session is active, the module SHALL provide `udk()` returning the established UDK and `identityPrivateKey()` returning the established 32-byte identity private key.

#### Scenario: Read UDK when active

- **WHEN** the session is active and `udk()` is called
- **THEN** the returned UDK matches the value passed to `establish`

#### Scenario: Read identity private key when active

- **WHEN** the session is active and `identityPrivateKey()` is called
- **THEN** the returned data matches the identity private key passed to `establish`

### Requirement: Key access when inactive

When the session is inactive, `udk()` and `identityPrivateKey()` SHALL throw `VaultSessionError.notActive`.

#### Scenario: UDK access throws when inactive

- **WHEN** the session is inactive and `udk()` is called
- **THEN** the call throws `VaultSessionError.notActive`

#### Scenario: Identity key access throws when inactive

- **WHEN** the session is inactive and `identityPrivateKey()` is called
- **THEN** the call throws `VaultSessionError.notActive`

### Requirement: Session activity observation

The module SHALL expose `changes: AsyncStream<Bool>` on `VaultSession` where `true` means active and `false` means inactive. The stream SHALL emit `true` after `establish` and `false` after `clear`. New subscribers SHALL receive the current `isActive` value immediately upon subscription. `clear` on an already inactive session SHALL NOT emit a new value.

#### Scenario: Establish emits active on changes stream

- **WHEN** a subscriber is listening to `changes` and `establish` is called
- **THEN** the stream yields `true`

#### Scenario: Clear emits inactive on changes stream

- **WHEN** a subscriber is listening to `changes`, the session is active, and `clear` is called
- **THEN** the stream yields `false`

#### Scenario: New subscriber receives current state

- **WHEN** a subscriber attaches to `changes` while the session is active
- **THEN** the stream immediately yields `true` before any subsequent mutations

#### Scenario: Idempotent clear does not emit

- **WHEN** a subscriber is listening to `changes` and `clear` is called on an already inactive session
- **THEN** the stream does not yield an additional value

### Requirement: VaultSessionError

The module SHALL define `VaultSessionError` with a `notActive` case. It SHALL conform to `Error`, `Equatable`, and `Sendable`.

#### Scenario: NotActive error is equatable

- **WHEN** two `VaultSessionError.notActive` values are compared
- **THEN** they are equal

### Requirement: Session does not perform authentication

The `VaultSession` module SHALL NOT implement password unlock, mnemonic recovery, biometrics, Keychain access, vault file I/O, lock timers, or navigation. It SHALL only store and expose in-memory keys and activity state.

#### Scenario: No unlock API on VaultSession

- **WHEN** the public API of `VaultSessionProtocol` is inspected
- **THEN** it does not include password, mnemonic, or vault unlock methods

### Requirement: Password change does not require session update

Because password change re-wraps the UDK in `vault.meta` without changing the UDK bytes, an active session SHALL remain valid and continue to return the same UDK and identity private key without requiring a new `establish` call.

#### Scenario: Keys unchanged across password change

- **WHEN** the session is active with a given UDK and identity private key, and a password change occurs in the auth layer without calling `clear` or `establish`
- **THEN** `udk()` and `identityPrivateKey()` still return the originally established values
