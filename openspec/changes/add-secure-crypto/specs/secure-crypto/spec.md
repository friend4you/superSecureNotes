## ADDED Requirements

### Requirement: Password key derivation protocol

The module SHALL define a `PasswordKeyDeriving` protocol that derives a 256-bit symmetric key from a password and salt. The protocol SHALL expose a method to serialize KDF parameters for storage in the vault header. The v1 implementation SHALL use PBKDF2-HMAC-SHA256 via CommonCrypto with a default iteration count of at least 600,000.

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

The module SHALL define a `RecoveryKeyDeriving` protocol that derives a 256-bit symmetric key from BIP39 mnemonic entropy (128 bits). The v1 implementation SHALL use HKDF-SHA256 via CryptoKit. Recovery derivation SHALL NOT require a stored salt.

#### Scenario: Derive recovery key from mnemonic entropy

- **WHEN** 128-bit BIP39 entropy bytes are provided to the default `HKDFRecoveryKeyDeriver`
- **THEN** the module returns a 256-bit `SymmetricKey` suitable for key wrapping

### Requirement: ChaChaPoly symmetric encryption

The module SHALL encrypt and decrypt data using ChaChaPoly (CryptoKit). Each encryption operation SHALL use a unique random 12-byte nonce. Ciphertext SHALL include the authentication tag.

#### Scenario: Encrypt and decrypt roundtrip

- **WHEN** plaintext `Data` is encrypted with a 256-bit symmetric key
- **THEN** decrypting the resulting ciphertext with the same key returns the original plaintext

#### Scenario: Tampered ciphertext is rejected

- **WHEN** ciphertext bytes are modified before decryption
- **THEN** decryption fails with an authentication error

### Requirement: Key wrapping

The module SHALL wrap (encrypt) and unwrap (decrypt) a 256-bit key using another 256-bit key via ChaChaPoly. Wrapped key blobs SHALL contain nonce, ciphertext, and authentication tag.

#### Scenario: Wrap and unwrap roundtrip

- **WHEN** a 256-bit FEK is wrapped with a 256-bit UDK
- **THEN** unwrapping the blob with the same UDK returns the original FEK

#### Scenario: Wrong wrapping key fails

- **WHEN** unwrap is attempted with a key different from the one used to wrap
- **THEN** unwrap fails with an authentication error

### Requirement: Symmetric key generation

The module SHALL provide a function to generate cryptographically random 256-bit symmetric keys using secure random bytes.

#### Scenario: Generate UDK

- **WHEN** `generateSymmetricKey()` is called
- **THEN** it returns a 256-bit key with full entropy

### Requirement: BIP39 mnemonic support

The module SHALL generate and validate 12-word BIP39 mnemonics using the English wordlist (2048 words). Generation SHALL use 128 bits of secure random entropy. Validation SHALL verify the BIP39 checksum.

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
