## 1. Protocol Abstractions

- [x] 1.1 Write failing tests: `AsymmetricKeyPairGenerating` mock returns 32-byte public and private key `Data`
- [x] 1.2 Define `AsymmetricKeyPairGenerating` protocol in `SecureCryptoProtocol`
- [x] 1.3 Write failing tests: `IdentityKeyWrapping` mock wrap/unwrap roundtrip and wrong-key failure
- [x] 1.4 Define `IdentityKeyWrapping` protocol in `SecureCryptoProtocol`

## 2. Asymmetric Key Pair Generation

- [x] 2.1 Write failing tests: `Curve25519KeyPairGenerator` returns 32-byte keys, unique pairs, public derivable from private
- [x] 2.2 Implement `Curve25519KeyPairGenerator` using `Curve25519.KeyAgreement.PrivateKey`
- [x] 2.3 Add `generateIdentityKeyPair()` convenience wrapper in `SecureCrypto`

## 3. Identity Private Key Wrapping

- [x] 3.1 Write failing tests: `UDKIdentityKeyWrapper` wrap/unwrap roundtrip, wrong UDK fails, tampered blob fails
- [x] 3.2 Implement `UDKIdentityKeyWrapper` delegating to `SymmetricCipher` (ChaChaPoly)
- [x] 3.3 Add `wrapIdentityPrivateKey` / `unwrapIdentityPrivateKey` convenience wrappers in `SecureCrypto`

## 4. Vault Header v2 Format

- [x] 4.1 Extend `VaultHeader` model with `identityAlgorithmID`, `identityPublicKey`, `wrappedIdentityPrivateKey` (optional for v1)
- [x] 4.2 Write failing tests: v2 header serialize → deserialize roundtrip with identity fields
- [x] 4.3 Implement v2 binary serialization (append algorithm ID, 32-byte public key, length-prefixed wrapped private key)
- [x] 4.4 Write failing tests: v1 header still parses without identity fields; v2 header rejects unsupported version
- [x] 4.5 Implement v1/v2 binary deserialization with version branching

## 5. Identity Unwrap API

- [x] 5.1 Write failing tests: unwrap identity after password unlock returns private key matching stored public key
- [x] 5.2 Write failing tests: unwrap identity after mnemonic recovery returns same private key as password unlock
- [x] 5.3 Write failing tests: unwrap on v1 header (no identity fields) fails with descriptive error
- [x] 5.4 Implement `unwrapIdentityPrivateKey(header:udk:)` with public/private key consistency check

## 6. Vault Lifecycle Updates

- [x] 6.1 Write failing tests: `createVault` returns v2 header with identity fields; key pair unique per vault
- [x] 6.2 Update `createVault(password:)` to generate identity key pair and wrap private key with UDK
- [x] 6.3 Write failing tests: v1 vault unlock upgrades to v2 header with new identity fields
- [x] 6.4 Update `unlockVault` to return upgraded v2 header when input is v1
- [x] 6.5 Write failing tests: v1 vault recovery upgrades to v2 header with new identity fields
- [x] 6.6 Update `recoverVault` to return upgraded v2 header when input is v1
- [x] 6.7 Write failing tests: password change preserves identity fields; identity unwrapable with new password
- [x] 6.8 Update `changePassword` to copy identity fields unchanged

## 7. Integration Verification

- [x] 7.1 Write failing tests: full flow create → unlock → unwrap identity → change password → unlock → same identity
- [x] 7.2 Write failing tests: full flow create → recover mnemonic → unwrap identity → same identity as password unlock
- [x] 7.3 Verify all existing vault lifecycle and header tests still pass (no regressions)
