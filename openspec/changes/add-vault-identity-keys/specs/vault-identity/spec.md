## ADDED Requirements

### Requirement: Asymmetric key pair generation

The module SHALL generate a Curve25519 (X25519) key pair consisting of a 32-byte public key and a 32-byte private key using a cryptographically secure random source.

#### Scenario: Generate key pair

- **WHEN** a new identity key pair is generated
- **THEN** the module returns a 32-byte public key and a 32-byte private key

#### Scenario: Key pairs are unique

- **WHEN** two key pairs are generated independently
- **THEN** each pair has distinct public and private key material

#### Scenario: Public key derivable from private key

- **WHEN** a key pair is generated
- **THEN** the public key matches the public key derived from the private key using Curve25519

### Requirement: Identity private key wrapping with UDK

The module SHALL wrap and unwrap the identity private key (32 raw bytes) using ChaChaPoly authenticated encryption with the vault UDK as the wrapping key.

#### Scenario: Wrap and unwrap roundtrip

- **WHEN** an identity private key is wrapped with a UDK and then unwrapped with the same UDK
- **THEN** the unwrapped private key matches the original

#### Scenario: Wrong UDK fails unwrap

- **WHEN** a wrapped identity private key is unwrapped with a different UDK
- **THEN** unwrap fails with an authentication error

#### Scenario: Tampered wrap fails

- **WHEN** a wrapped identity private key blob is modified and unwrapped
- **THEN** unwrap fails with an authentication error

### Requirement: Identity fields in vault header

The module SHALL store identity material in `vault.meta` v2: `identity_algorithm_id` (UInt8), `identity_public_key` (32 bytes plaintext), and `wrapped_identity_private_key` (length-prefixed ChaChaPoly blob).

#### Scenario: v2 header contains identity fields

- **WHEN** a v2 vault header is serialized
- **THEN** the blob includes algorithm ID, public key, and wrapped private key after existing v1 fields

#### Scenario: Parse v2 header with identity

- **WHEN** a valid v2 `vault.meta` blob is parsed
- **THEN** the module returns structured identity fields alongside existing KDF and UDK wrap fields

#### Scenario: Public key is not encrypted

- **WHEN** a v2 vault header is parsed
- **THEN** the identity public key is readable without decryption

### Requirement: Identity unwrap after unlock

The module SHALL provide an API to unwrap the identity private key from a v2 vault header using the UDK obtained from password unlock or mnemonic recovery.

#### Scenario: Unwrap identity after password unlock

- **WHEN** a vault is unlocked with the correct password and the header contains identity fields
- **THEN** the module returns the identity private key that corresponds to the stored public key

#### Scenario: Unwrap identity after mnemonic recovery

- **WHEN** a vault is recovered with the correct mnemonic and the header contains identity fields
- **THEN** the module returns the same identity private key as password unlock would produce

#### Scenario: Unwrap fails without identity fields

- **WHEN** unwrap identity is called on a v1 header without identity fields
- **THEN** the operation fails with a descriptive error

### Requirement: Identity preserved across password change

The identity public key and wrapped private key SHALL NOT change when the vault password is changed. Only `wrapped_udk_password` is re-wrapped.

#### Scenario: Password change preserves identity

- **WHEN** the vault password is changed successfully
- **THEN** the updated header contains the same `identity_public_key` and `wrapped_identity_private_key` as before

#### Scenario: Identity unwrapable after password change

- **WHEN** the password is changed and the vault is unlocked with the new password
- **THEN** the unwrapped identity private key matches the pre-change identity private key
