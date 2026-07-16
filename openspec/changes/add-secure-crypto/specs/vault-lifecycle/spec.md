## ADDED Requirements

### Requirement: Vault header format

The module SHALL define a versioned binary `vault.meta` format with magic bytes `SSNV`, version byte, KDF parameters, and two wrapped UDK blobs. Fields SHALL include: `kdf_id`, `salt` (32 bytes), `iterations`, `wrapped_udk_password`, and `wrapped_udk_recovery`.

#### Scenario: Serialize vault header

- **WHEN** vault creation completes with a UDK, password KEK, and recovery KEK
- **THEN** the module produces a `vault.meta` byte blob containing both wrapped UDK entries and KDF parameters

#### Scenario: Parse vault header

- **WHEN** a valid `vault.meta` blob is parsed
- **THEN** the module returns structured fields including salt, KDF parameters, and both wrapped UDK blobs

#### Scenario: Reject invalid vault header

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed
- **THEN** parsing fails with a descriptive error

### Requirement: Vault creation

The module SHALL support creating a new vault by generating a random UDK, deriving KEK from password, generating a BIP39 recovery phrase, deriving recovery KEK from mnemonic entropy, wrapping UDK with both KEKs, and producing a `vault.meta` blob. The recovery mnemonic SHALL be returned to the caller and SHALL NOT be persisted by the module.

#### Scenario: Create vault with password and recovery

- **WHEN** `createVault(password:)` is called
- **THEN** the module returns a `VaultCreationResult` containing `vault.meta` bytes and a 12-word recovery mnemonic

#### Scenario: UDK is unique per vault

- **WHEN** two vaults are created independently
- **THEN** each vault has a distinct randomly generated UDK

### Requirement: Vault unlock with password

The module SHALL unlock a vault by parsing `vault.meta`, deriving KEK from the provided password and stored salt, and unwrapping `wrapped_udk_password` to recover the UDK.

#### Scenario: Successful password unlock

- **WHEN** the correct password is provided for a vault
- **THEN** the module returns the UDK

#### Scenario: Wrong password fails

- **WHEN** an incorrect password is provided
- **THEN** unlock fails with an authentication error (unwrap failure)

### Requirement: Vault recovery with mnemonic

The module SHALL recover a vault by validating a 12-word BIP39 phrase, deriving recovery KEK from entropy, and unwrapping `wrapped_udk_recovery` to recover the UDK.

#### Scenario: Successful mnemonic recovery

- **WHEN** the correct 12-word recovery phrase is provided
- **THEN** the module returns the same UDK that password unlock would produce

#### Scenario: Wrong mnemonic fails

- **WHEN** an incorrect recovery phrase is provided
- **THEN** recovery fails with an authentication error

### Requirement: Password change

The module SHALL support changing the vault password by unwrapping UDK with the old password KEK and re-wrapping with a new password KEK. Note files and recovery wrap SHALL NOT change. UDK and per-note FEKs SHALL NOT change.

#### Scenario: Change password successfully

- **WHEN** the correct old password and a new password are provided
- **THEN** the module returns updated `vault.meta` bytes with a new `wrapped_udk_password` and the same UDK, salt, and `wrapped_udk_recovery`

#### Scenario: Wrong old password rejected

- **WHEN** an incorrect old password is provided during password change
- **THEN** the operation fails without modifying any data

#### Scenario: Notes remain readable after password change

- **WHEN** password is changed and a note file is decrypted with the UDK obtained via new password
- **THEN** the note decrypts successfully without re-encryption

### Requirement: Salt is per-vault

Each vault SHALL have its own random 32-byte salt stored in `vault.meta`. Changing salt or password in one vault SHALL NOT affect any other vault.

#### Scenario: Independent vault salts

- **WHEN** two vaults exist on the same device
- **THEN** each `vault.meta` contains a distinct salt
