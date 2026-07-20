## Context

`SecureCrypto` currently implements a symmetric-only key hierarchy: password or mnemonic → KEK → UDK → per-note FEK. The `vault.meta` format (v1) stores KDF parameters and two UDK wraps. Note sharing requires a per-vault asymmetric identity so recipients can encrypt content for the vault owner.

Exploration decisions (captured):
- **Vault-recoverable identity**: private key wrapped with UDK (same recovery path as notes)
- **Public key in vault**: stored plaintext in `vault.meta`
- **Keychain is optional cache**: owned by auth module, not this change
- **Per-vault identity**: one Curve25519 key pair per vault

Constraints unchanged: native Apple frameworks only (CryptoKit), strict TDD, protocol abstractions in `SecureCryptoProtocol`, implementations in `SecureCrypto`.

## Goals / Non-Goals

**Goals:**

- Generate a Curve25519 (X25519) key pair at vault creation
- Store plaintext public key and UDK-wrapped private key in `vault.meta` v2
- Unwrap identity private key using UDK after password unlock or mnemonic recovery
- Preserve identity across password change (wrapped with UDK, not password KEK)
- Migrate v1 vault headers to v2 lazily on unlock
- Expose protocol abstractions for testability and dependency injection

**Non-Goals:**

- Keychain read/write or session caching (auth module)
- Contact public key storage or distribution UX
- Encrypting note FEKs for recipients (future sharing change)
- Ed25519 message signing or sender authentication
- Identity key rotation or revocation
- Forward secrecy (ephemeral per-share keys)

## Decisions

### 1. Algorithm: Curve25519 key agreement (X25519)

Use `Curve25519.KeyAgreement.PrivateKey` / `PublicKey` from CryptoKit.

**Rationale:** Native, modern, 32-byte keys, standard for ECDH-based encryption. Aligns with "Apple frameworks only" constraint.

**Alternatives considered:**
- P-256 (`P256.KeyAgreement`) — equally native; Curve25519 preferred for size and performance
- Ed25519 signing keys — useful for authentication later; out of scope for identity encryption v1

### 2. Identity key hierarchy (extends existing envelope model)

```
password/mnemonic → KEK → UDK
                            ├── wrap → FEK (per note, existing)
                            └── wrap → identity private key (new)
                            └── plaintext → identity public key (new)
```

**Rationale:** Mirrors UDK → FEK wrapping. Password change re-wraps UDK only; identity blob unchanged. Mnemonic recovery yields same UDK and therefore same identity private key.

### 3. Private key wrapping: ChaChaPoly via UDK

Serialize `privateKey.rawRepresentation` (32 bytes) and encrypt with ChaChaPoly using UDK as the wrapping key — same mechanism as `KeyWrapping` / `wrapKey`.

Introduce `IdentityKeyWrapping` protocol with `wrapPrivateKey(_:with:)` / `unwrapPrivateKey(_:with:)` operating on `Data` and `SymmetricKey` (UDK). Implementation delegates to existing `SymmetricCipher`.

**Rationale:** Reuses tested ChaChaPoly path. Private key is not a `SymmetricKey`, so a dedicated protocol avoids overloading `KeyWrapping`.

**Alternatives considered:**
- Store private key in Keychain only — rejected; not recoverable via mnemonic
- Derive identity private key deterministically from mnemonic — rejected; couples identity to phrase exposure

### 4. vault.meta v2 format

Bump `formatVersion` to `2`. Append after existing v1 fields:

| Field | Type | Notes |
|-------|------|-------|
| `identity_algorithm_id` | UInt8 | `1` = Curve25519 |
| `identity_public_key` | 32 fixed bytes | plaintext |
| `wrapped_identity_private_key` | length-prefixed | ChaChaPoly blob |

v1 headers (version byte `1`) parse without identity fields. Parser returns a `VaultHeader` that indicates whether identity is present.

**Rationale:** Backward-compatible parsing. New vaults always v2.

### 5. Lazy v1 → v2 migration on unlock

When a v1 header is unlocked:
1. Derive UDK (existing flow)
2. Generate new identity key pair
3. Wrap private key with UDK
4. Return upgraded v2 `VaultHeader` alongside UDK

Caller (app) persists the upgraded header. Crypto module does not write to disk.

**Rationale:** No batch migration tool needed. First unlock after upgrade transparently adds identity.

**Alternatives considered:**
- Explicit `migrateVaultToV2` API — more control but worse UX; lazy migration preferred

### 6. Protocol surface

| Protocol | Module | Methods |
|----------|--------|---------|
| `AsymmetricKeyPairGenerating` | `SecureCryptoProtocol` | `generateKeyPair() -> (publicKey: Data, privateKey: Data)` |
| `IdentityKeyWrapping` | `SecureCryptoProtocol` | `wrapPrivateKey(_:with:)`, `unwrapPrivateKey(_:with:)` |

Concrete types in `SecureCrypto`:
- `Curve25519KeyPairGenerator: AsymmetricKeyPairGenerating`
- `UDKIdentityKeyWrapper: IdentityKeyWrapping`

Free-function convenience wrappers in `SecureCrypto` follow existing pattern (`generateSymmetricKey`, `wrapKey`, etc.).

### 7. Identity unwrap API

```swift
func unwrapIdentityPrivateKey(header: VaultHeader, udk: SymmetricKey) throws -> Data
```

Returns raw 32-byte private key `Data`. App/auth module converts to `Curve25519.KeyAgreement.PrivateKey` or caches in Keychain. Crypto module stays Keychain-free.

On unlock, caller can verify consistency: derived public key from unwrapped private key matches `header.identityPublicKey`.

### 8. Password change behavior

`changePassword` re-wraps `wrapped_udk_password` only. Identity fields (`identity_public_key`, `wrapped_identity_private_key`) are copied unchanged — same rule as `wrapped_udk_recovery` and note FEKs.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| UDK compromise exposes identity private key | Same threat model as all note FEKs; documented |
| No forward secrecy with static identity key | Accept for v1; ephemeral per-share keys deferred |
| v1 vaults get new identity on first unlock post-migration | Documented; no pre-migration shared notes exist yet |
| Algorithm ID `1` may need future alternatives | `identity_algorithm_id` byte enables format evolution |
| Private key in memory during session | Auth module clears on lock; out of scope here |
| CryptoKit type coupling in protocol module | Consistent with existing `SymmetricKey` references |

## Migration Plan

1. Deploy updated `SecureCrypto` package with v1 + v2 header parsing
2. New vaults created as v2 with identity automatically
3. Existing v1 vaults: on first `unlockVault`, app receives upgraded v2 header and persists it
4. Rollback: if app downgrades package, v2 headers with trailing identity fields may fail parse on old version — acceptable for pre-release; production would need version negotiation

No note file format changes. No UDK or FEK changes.

## Open Questions

None — all decisions resolved during exploration.
