## MODIFIED Requirements

### Requirement: Password key derivation protocol

The `SecureCrypto` module SHALL provide a `PBKDF2KeyDeriver` conforming to `PasswordKeyDeriving` (defined in `SecureCryptoProtocol`). The protocol and `PasswordKeyDeriving` type SHALL NOT be defined in `SecureCrypto`. The v1 implementation SHALL use PBKDF2-HMAC-SHA256 via CommonCrypto with a default iteration count of at least 600,000.

#### Scenario: Derive password key with default parameters

- **WHEN** a password and 32-byte random salt are provided to the default `PBKDF2KeyDeriver`
- **THEN** the module returns a 256-bit `SymmetricKey` suitable for key wrapping

#### Scenario: KDF parameters are serializable

- **WHEN** the KDF implementation produces parameters (algorithm id, iterations, salt)
- **THEN** the module serializes them into a byte blob storable in `vault.meta`

#### Scenario: KDF implementation is swappable

- **WHEN** a custom type conforms to `PasswordKeyDeriving`
- **THEN** vault operations accept it via dependency injection without changing encrypt/decrypt APIs

### Requirement: Recovery key derivation protocol

The `SecureCrypto` module SHALL provide an `HKDFRecoveryKeyDeriver` conforming to `RecoveryKeyDeriving` (defined in `SecureCryptoProtocol`). The protocol and `RecoveryKeyDeriving` type SHALL NOT be defined in `SecureCrypto`. The v1 implementation SHALL use HKDF-SHA256 via CryptoKit. Recovery derivation SHALL NOT require a stored salt.

#### Scenario: Derive recovery key from mnemonic entropy

- **WHEN** 128-bit BIP39 entropy bytes are provided to the default `HKDFRecoveryKeyDeriver`
- **THEN** the module returns a 256-bit `SymmetricKey` suitable for key wrapping

### Requirement: ChaChaPoly symmetric encryption

The `SecureCrypto` module SHALL provide a `ChaChaPolyCipher` type conforming to `SymmetricCipher` (defined in `SecureCryptoProtocol`). Encryption SHALL use ChaChaPoly (CryptoKit). Each encryption operation SHALL use a unique random 12-byte nonce. Ciphertext SHALL include the authentication tag. Free-function `encrypt`/`decrypt` MAY be retained as convenience wrappers.

#### Scenario: Encrypt and decrypt roundtrip

- **WHEN** plaintext `Data` is encrypted with a 256-bit symmetric key
- **THEN** decrypting the resulting ciphertext with the same key returns the original plaintext

#### Scenario: Tampered ciphertext is rejected

- **WHEN** ciphertext bytes are modified before decryption
- **THEN** decryption fails with an authentication error

### Requirement: Key wrapping

The `SecureCrypto` module SHALL provide a `ChaChaPolyKeyWrapper` type conforming to `KeyWrapping` (defined in `SecureCryptoProtocol`). Wrapping SHALL encrypt a 256-bit key using another 256-bit key via ChaChaPoly. Wrapped key blobs SHALL contain nonce, ciphertext, and authentication tag. Free-function `wrapKey`/`unwrapKey` MAY be retained as convenience wrappers.

#### Scenario: Wrap and unwrap roundtrip

- **WHEN** a 256-bit FEK is wrapped with a 256-bit UDK
- **THEN** unwrapping the blob with the same UDK returns the original FEK

#### Scenario: Wrong wrapping key fails

- **WHEN** unwrap is attempted with a key different from the one used to wrap
- **THEN** unwrap fails with an authentication error

### Requirement: Symmetric key generation

The `SecureCrypto` module SHALL provide a `CryptoKitKeyGenerator` type conforming to `SymmetricKeyGenerating` (defined in `SecureCryptoProtocol`) that generates cryptographically random 256-bit symmetric keys. Free-function `generateSymmetricKey()` MAY be retained as a convenience wrapper.

#### Scenario: Generate UDK

- **WHEN** `generateSymmetricKey()` is called
- **THEN** it returns a 256-bit key with full entropy

### Requirement: BIP39 mnemonic support

The `SecureCrypto` module SHALL provide a `BIP39MnemonicEncoder` type conforming to `MnemonicEncoding` (defined in `SecureCryptoProtocol`). It SHALL use the English wordlist from `SecureCryptoProtocol`. Generation SHALL use 128 bits of secure random entropy. Validation SHALL verify the BIP39 checksum. The existing `BIP39Mnemonic` enum namespace MAY be retained as a convenience facade delegating to the default encoder.

#### Scenario: Generate recovery mnemonic

- **WHEN** a new recovery phrase is requested during vault creation
- **THEN** the module returns exactly 12 English words encoding 128-bit entropy

#### Scenario: Validate correct mnemonic

- **WHEN** a valid 12-word BIP39 phrase is submitted
- **THEN** validation succeeds and returns the 128-bit entropy bytes

#### Scenario: Reject invalid mnemonic checksum

- **WHEN** a 12-word phrase with an invalid checksum is submitted
- **THEN** validation fails with a descriptive error

#### Scenario: Reject wrong word count

- **WHEN** a phrase with fewer or more than 12 words is submitted
- **THEN** validation fails with a descriptive error
