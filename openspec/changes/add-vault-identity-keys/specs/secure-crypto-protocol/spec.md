## ADDED Requirements

### Requirement: Asymmetric key pair generation protocol

The `SecureCryptoProtocol` module SHALL define an `AsymmetricKeyPairGenerating` protocol with a `generateKeyPair()` method returning a tuple of `(publicKey: Data, privateKey: Data)` where each value is 32 bytes.

#### Scenario: Protocol contract for key pair generation

- **WHEN** a type conforms to `AsymmetricKeyPairGenerating`
- **THEN** it provides `generateKeyPair()` returning 32-byte public and private key `Data` values

#### Scenario: Protocol is Sendable

- **WHEN** an `AsymmetricKeyPairGenerating` instance is passed across concurrency domains
- **THEN** the protocol conformance includes `Sendable`

#### Scenario: Protocol enables test doubles

- **WHEN** vault creation needs an identity key pair
- **THEN** it accepts an `AsymmetricKeyPairGenerating` instance for deterministic testing

### Requirement: Identity key wrapping protocol

The `SecureCryptoProtocol` module SHALL define an `IdentityKeyWrapping` protocol with `wrapPrivateKey(_:with:)` and `unwrapPrivateKey(_:with:)` methods. The private key parameter SHALL be 32 bytes of raw key material. The wrapping key SHALL be a 256-bit `SymmetricKey` (UDK).

#### Scenario: Wrap protocol contract

- **WHEN** a type conforms to `IdentityKeyWrapping`
- **THEN** it provides `wrapPrivateKey(_:with:)` returning encrypted `Data` and `unwrapPrivateKey(_:with:)` returning the original 32-byte private key

#### Scenario: Wrap protocol enables dependency injection

- **WHEN** vault code needs to wrap or unwrap an identity private key
- **THEN** it accepts an `IdentityKeyWrapping` instance rather than calling free functions

#### Scenario: Protocol is Sendable

- **WHEN** an `IdentityKeyWrapping` instance is passed across concurrency domains
- **THEN** the protocol conformance includes `Sendable`
