## ADDED Requirements

### Requirement: Recipient FEK wrap for sharing

The `SecureCrypto` module SHALL provide `wrapFEKForRecipient(_ fek: SymmetricKey, recipientPublicKey: Data) throws -> Data` that produces a versioned wire blob with magic `SSNF`, version `1`, algorithm ID `1` (Curve25519), a 32-byte ephemeral X25519 public key, and a ChaChaPoly-wrapped FEK. The wrapping key SHALL be derived via HKDF-SHA256 from the X25519 shared secret with info string `"superSecureNotes.share.fek.v1"` and 32-byte output. `recipientPublicKey` SHALL be exactly 32 bytes.

#### Scenario: Wrap produces parseable wire blob

- **WHEN** `wrapFEKForRecipient` is called with a valid FEK and 32-byte recipient public key
- **THEN** the returned data begins with magic `SSNF`, version `1`, and algorithm ID `1`

#### Scenario: Reject invalid recipient public key length

- **WHEN** `wrapFEKForRecipient` is called with a public key that is not 32 bytes
- **THEN** it throws a descriptive error

### Requirement: Shared grant FEK unwrap for recipients

The `SecureCrypto` module SHALL provide `unwrapSharedFEK(_ wrapped: Data, identityPrivateKey: Data) throws -> SymmetricKey` that parses a `SSNF` v1 Curve25519 share wire blob, performs X25519 key agreement with the embedded ephemeral public key using `identityPrivateKey`, derives the same HKDF wrapping key, and unwraps the FEK using the existing symmetric unwrap primitive.

#### Scenario: Roundtrip wrap then unwrap

- **WHEN** a FEK is wrapped for a recipient key pair and unwrapped with that recipient's private key
- **THEN** the unwrapped FEK matches the original

#### Scenario: Reject tampered wire blob

- **WHEN** `unwrapSharedFEK` is called with data that has invalid magic or version
- **THEN** it throws a descriptive error
