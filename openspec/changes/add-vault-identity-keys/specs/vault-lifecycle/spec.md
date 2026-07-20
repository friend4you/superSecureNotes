## MODIFIED Requirements

### Requirement: Vault header format

The module SHALL define a versioned binary `vault.meta` format with magic bytes `SSNV`, version byte, KDF parameters, two wrapped UDK blobs, and (for version 2) identity fields. Version 1 fields SHALL include: `kdf_id`, `salt` (32 bytes), `iterations`, `wrapped_udk_password`, and `wrapped_udk_recovery`. Version 2 SHALL additionally include: `identity_algorithm_id` (UInt8), `identity_public_key` (32 bytes), and `wrapped_identity_private_key` (length-prefixed).

#### Scenario: Serialize vault header

- **WHEN** vault creation completes with a UDK, password KEK, recovery KEK, and identity key pair
- **THEN** the module produces a `vault.meta` v2 byte blob containing both wrapped UDK entries, KDF parameters, and identity fields

#### Scenario: Parse vault header

- **WHEN** a valid `vault.meta` blob is parsed
- **THEN** the module returns structured fields including salt, KDF parameters, both wrapped UDK blobs, and identity fields when version is 2

#### Scenario: Parse v1 vault header

- **WHEN** a valid v1 `vault.meta` blob (version byte 1) is parsed
- **THEN** the module returns structured v1 fields and indicates identity fields are absent

#### Scenario: Reject invalid vault header

- **WHEN** a blob with incorrect magic bytes or unsupported version is parsed
- **THEN** parsing fails with a descriptive error

### Requirement: Vault creation

The module SHALL support creating a new vault by generating a random UDK, deriving KEK from password, generating a BIP39 recovery phrase, deriving recovery KEK from mnemonic entropy, wrapping UDK with both KEKs, generating a Curve25519 identity key pair, wrapping the identity private key with UDK, and producing a v2 `vault.meta` blob. The recovery mnemonic SHALL be returned to the caller and SHALL NOT be persisted by the module.

#### Scenario: Create vault with password and recovery

- **WHEN** `createVault(password:)` is called
- **THEN** the module returns a `VaultCreationResult` containing a v2 `vault.meta` header and a 12-word recovery mnemonic

#### Scenario: UDK is unique per vault

- **WHEN** two vaults are created independently
- **THEN** each vault has a distinct randomly generated UDK

#### Scenario: Identity key pair created at vault creation

- **WHEN** `createVault(password:)` is called
- **THEN** the returned header contains a unique identity public key and a wrapped identity private key

### Requirement: Vault unlock with password

The module SHALL unlock a vault by parsing `vault.meta`, deriving KEK from the provided password and stored salt, and unwrapping `wrapped_udk_password` to recover the UDK. For v1 headers, the module SHALL additionally generate an identity key pair, wrap the private key with UDK, and return an upgraded v2 header.

#### Scenario: Successful password unlock

- **WHEN** the correct password is provided for a vault
- **THEN** the module returns the UDK

#### Scenario: Wrong password fails

- **WHEN** an incorrect password is provided
- **THEN** unlock fails with an authentication error (unwrap failure)

#### Scenario: v1 vault upgraded on unlock

- **WHEN** a v1 vault header is unlocked with the correct password
- **THEN** the module returns the UDK and an upgraded v2 header containing newly generated identity fields

### Requirement: Vault recovery with mnemonic

The module SHALL recover a vault by validating a 12-word BIP39 phrase, deriving recovery KEK from entropy, and unwrapping `wrapped_udk_recovery` to recover the UDK. For v1 headers, the module SHALL additionally generate an identity key pair, wrap the private key with UDK, and return an upgraded v2 header.

#### Scenario: Successful mnemonic recovery

- **WHEN** the correct 12-word recovery phrase is provided
- **THEN** the module returns the same UDK that password unlock would produce

#### Scenario: Wrong mnemonic fails

- **WHEN** an incorrect recovery phrase is provided
- **THEN** recovery fails with an authentication error

#### Scenario: v1 vault upgraded on recovery

- **WHEN** a v1 vault header is recovered with the correct mnemonic
- **THEN** the module returns the UDK and an upgraded v2 header containing newly generated identity fields

### Requirement: Password change

The module SHALL support changing the vault password by unwrapping UDK with the old password KEK and re-wrapping with a new password KEK. Note files and recovery wrap SHALL NOT change. UDK, per-note FEKs, and identity fields SHALL NOT change.

#### Scenario: Change password successfully

- **WHEN** the correct old password and a new password are provided
- **THEN** the module returns updated `vault.meta` bytes with a new `wrapped_udk_password` and the same UDK, salt, `wrapped_udk_recovery`, and identity fields

#### Scenario: Wrong old password rejected

- **WHEN** an incorrect old password is provided during password change
- **THEN** the operation fails without modifying any data

#### Scenario: Notes remain readable after password change

- **WHEN** password is changed and a note file is decrypted with the UDK obtained via new password
- **THEN** the note decrypts successfully without re-encryption

#### Scenario: Identity remains recoverable after password change

- **WHEN** password is changed and identity private key is unwrapped with UDK from new password
- **THEN** the identity private key matches the pre-change identity private key
