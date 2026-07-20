## Why

Note sharing requires a stable per-vault identity (public/private key pair). The vault must recover that identity through the same password and mnemonic paths as the UDK, so shared notes remain accessible after device loss or vault recovery. This change adds vault-scoped asymmetric identity keys with UDK-wrapped private key storage in `vault.meta`.

## What Changes

- Add Curve25519 (X25519) key pair generation to `SecureCrypto` behind new protocol abstractions in `SecureCryptoProtocol`
- Extend `vault.meta` to format version 2 with `identity_algorithm_id`, plaintext `identity_public_key`, and `wrapped_identity_private_key` (ChaChaPoly-encrypted with UDK)
- Update vault creation to generate an identity key pair and persist both halves in the vault header
- Add helpers to unwrap the identity private key from the vault header using UDK (password unlock or mnemonic recovery)
- Support lazy migration: v1 vault headers upgraded to v2 on unlock by generating a new identity key pair
- **BREAKING**: `VaultHeader.formatVersion` becomes `2` for new vaults; v1 headers remain parseable

## Capabilities

### New Capabilities

- `vault-identity`: Per-vault asymmetric identity — key pair generation, UDK-wrapped private key storage, public key in vault header, unwrap after unlock/recovery

### Modified Capabilities

- `vault-lifecycle`: Vault creation, unlock, recovery, and password change extended for identity key generation, v2 header format, and v1→v2 migration on unlock
- `secure-crypto-protocol`: New protocol abstractions for asymmetric key pair generation and identity private key wrapping/unwrapping

## Impact

- `Packages/SecureCrypto/Sources/SecureCryptoProtocol/` — new protocols (`AsymmetricKeyPairGenerating`, `IdentityKeyWrapping`)
- `Packages/SecureCrypto/Sources/SecureCrypto/` — Curve25519 implementation, updated `VaultHeader`, updated `VaultLifecycle`
- `Packages/SecureCrypto/Tests/` — protocol contract tests and implementation roundtrip/migration tests (TDD, tests before implementation)
- Out of scope: Keychain caching (auth module), contact public key storage, encrypting note FEKs for recipients, Ed25519 signing
