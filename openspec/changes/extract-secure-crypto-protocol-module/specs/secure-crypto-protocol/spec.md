## ADDED Requirements

### Requirement: SecureCryptoProtocol module

The repository SHALL provide a Swift Package target `SecureCryptoProtocol` that exports only crypto contracts and shared types. The target SHALL NOT import CommonCrypto or contain algorithm implementations. Feature modules SHALL depend on `SecureCryptoProtocol` instead of `SecureCrypto` when they need crypto abstractions.

#### Scenario: Feature module imports protocols only

- **WHEN** a feature module (e.g. vault lifecycle) needs key derivation or cipher contracts
- **THEN** it imports `SecureCryptoProtocol` and does not import `SecureCrypto`

#### Scenario: Protocol module has no implementation dependencies

- **WHEN** `SecureCryptoProtocol` is built in isolation
- **THEN** it compiles with only Foundation and CryptoKit (for `SymmetricKey` type references)

### Requirement: Password key derivation protocol

The `SecureCryptoProtocol` module SHALL define a `PasswordKeyDeriving` protocol that derives a 256-bit symmetric key from a password and salt, exposes an algorithm identifier and iteration count, and serializes KDF parameters for vault header storage.

#### Scenario: Protocol contract for password KDF

- **WHEN** a type conforms to `PasswordKeyDeriving`
- **THEN** it provides `deriveKey(password:salt:)` returning `SymmetricKey` and `serializeParameters(salt:)` returning `Data`

#### Scenario: Protocol is Sendable

- **WHEN** a `PasswordKeyDeriving` instance is passed across concurrency domains
- **THEN** the protocol conformance includes `Sendable`

### Requirement: Recovery key derivation protocol

The `SecureCryptoProtocol` module SHALL define a `RecoveryKeyDeriving` protocol that derives a 256-bit symmetric key from BIP39 mnemonic entropy (128 bits) without requiring a stored salt.

#### Scenario: Protocol contract for recovery KDF

- **WHEN** a type conforms to `RecoveryKeyDeriving`
- **THEN** it provides `deriveKey(entropy:)` returning `SymmetricKey`

### Requirement: Symmetric cipher protocol

The `SecureCryptoProtocol` module SHALL define a `SymmetricCipher` protocol with `encrypt(_:key:)` and `decrypt(_:key:)` methods operating on `Data` and `SymmetricKey`.

#### Scenario: Cipher protocol enables dependency injection

- **WHEN** vault or note code needs encrypt/decrypt operations
- **THEN** it accepts a `SymmetricCipher` instance rather than calling free functions

### Requirement: Key wrapping protocol

The `SecureCryptoProtocol` module SHALL define a `KeyWrapping` protocol with `wrapKey(_:with:)` and `unwrapKey(_:with:)` methods for 256-bit key material.

#### Scenario: Wrap protocol enables dependency injection

- **WHEN** vault code needs to wrap or unwrap a UDK or FEK
- **THEN** it accepts a `KeyWrapping` instance rather than calling free functions

### Requirement: Symmetric key generation protocol

The `SecureCryptoProtocol` module SHALL define a `SymmetricKeyGenerating` protocol with a `generateSymmetricKey()` method returning a 256-bit `SymmetricKey`.

#### Scenario: Key generation protocol enables test doubles

- **WHEN** vault creation needs a random UDK
- **THEN** it accepts a `SymmetricKeyGenerating` instance for deterministic testing

### Requirement: BIP39 mnemonic protocol

The `SecureCryptoProtocol` module SHALL define a `MnemonicEncoding` protocol that converts 128-bit entropy to 12 English words, validates a 12-word phrase, and extracts entropy. Constants `wordCount` (12) and `entropyLength` (16 bytes) SHALL be exposed.

#### Scenario: Mnemonic protocol contract

- **WHEN** a type conforms to `MnemonicEncoding`
- **THEN** it provides `words(from:)`, `validate(_:)`, and `entropy(from:)` with the same semantics as the existing `BIP39Mnemonic` API

### Requirement: Shared error type

The `SecureCryptoProtocol` module SHALL define `SecureCryptoError` with cases for insufficient data, invalid magic, unsupported version, authentication failure, invalid input, and decoding failure. It SHALL conform to `Error`, `Equatable`, `Sendable`, and `LocalizedError`.

#### Scenario: Errors are shared across modules

- **WHEN** a feature module catches crypto errors from protocol operations
- **THEN** it uses `SecureCryptoError` from `SecureCryptoProtocol` without importing `SecureCrypto`

### Requirement: Byte buffer helper

The `SecureCryptoProtocol` module SHALL define `ByteBuffer` for length-prefixed binary serialization used by vault header and note format layers.

#### Scenario: Format layers use shared buffer type

- **WHEN** vault header serialization reads or writes length-prefixed fields
- **THEN** it uses `ByteBuffer` from `SecureCryptoProtocol`

### Requirement: BIP39 English wordlist resource

The `SecureCryptoProtocol` module SHALL bundle the BIP39 English wordlist (`english.txt`, 2048 words) as a processed bundle resource and expose a public `BIP39Wordlist` type for word lookup and validation.

#### Scenario: Wordlist is accessible from protocol module

- **WHEN** mnemonic encoding or UI word validation needs the BIP39 word list
- **THEN** `BIP39Wordlist` loads 2048 words from `Bundle.module` without importing `SecureCrypto`

#### Scenario: Unknown word detection

- **WHEN** `BIP39Wordlist.index(of:)` is called with a word not in the list
- **THEN** it returns `nil`
