## Context

superSecureNotes is a greenfield SwiftUI iOS app (iOS 17+) for offline, single-user encrypted notes. No crypto exists today. The app will eventually include auth (biometrics, lock timing), but this change delivers a standalone `SecureCrypto` Swift Package that handles key derivation, encryption, and binary format serialization only.

Constraints from exploration:
- Native Apple frameworks only (CryptoKit + CommonCrypto)
- Lower-level API: app assembles `.note` files; crypto module does not manage filesystem lifecycle or deletion
- Per-note FEK (File Encryption Key) wrapped by vault-level UDK (User Data Key)
- 12-word BIP39 English recovery phrase as second path to UDK
- Plaintext note metadata (title, dates, attachment stats) for list UI without decryption

## Goals / Non-Goals

**Goals:**

- Provide a testable Swift Package at `Packages/SecureCrypto/` with iOS 17+ deployment target
- Implement key hierarchy: password/mnemonic → KEK → UDK → FEK → note payload
- Use ChaChaPoly (CryptoKit) for all symmetric encryption
- Use PBKDF2-SHA256 (CommonCrypto, 600,000+ iterations) behind `PasswordKeyDeriving` protocol
- Use HKDF-SHA256 (CryptoKit) behind `RecoveryKeyDeriving` protocol
- Serialize/parse `vault.meta` and `.note` binary formats (versioned)
- Support vault creation, password unlock, mnemonic recovery, password change (re-wrap UDK)
- Expose `NoteMetadata` parser for plaintext `.note` headers (index rebuild without decrypt)

**Non-Goals:**

- Auth module (biometrics, Keychain, lock/session management)
- Note deletion, `index.json` management, tags
- Attachment size limits (app-layer policy)
- Argon2 or third-party crypto libraries
- Multi-user, sync, or cloud storage
- Protocol abstraction for cipher or key wrapping (concrete ChaChaPoly only in v1)
- Streaming encryption for large attachments

## Decisions

### 1. Key hierarchy (envelope encryption)

```
password + salt ──PBKDF2──▶ KEK_password ──┐
                                            ├── wrap ──▶ UDK (256-bit random)
BIP39 entropy ──HKDF────▶ KEK_recovery  ──┘
                                            │
                                            ├── wrap ──▶ FEK₁ (per note)
                                            ├── wrap ──▶ FEK₂
                                            └── ...
```

**Rationale:** Password change re-wraps only UDK (one small blob). Note ciphertext and FEKs are unchanged. Recovery phrase provides independent unlock path to same UDK.

**Alternatives considered:**
- Single DEK per vault: simpler but all notes share one key; rejected for per-note isolation
- Encrypt notes directly with password KEK: password change would require re-encrypting all notes

### 2. KDF protocols (swappable password derivation only)

| Protocol | v1 Implementation | Input | Speed |
|----------|-------------------|-------|-------|
| `PasswordKeyDeriving` | `PBKDF2KeyDeriver` | password + salt | Slow (600k iter) |
| `RecoveryKeyDeriving` | `HKDFRecoveryKeyDeriver` | 128-bit BIP39 entropy | Fast (entropy already random) |

**Rationale:** Password needs brute-force resistance. Recovery entropy is 128-bit random — slow KDF unnecessary. Protocol on password path allows future Argon2 swap without API changes.

### 3. Cipher: ChaChaPoly

All encryption (UDK wraps, FEK wraps, note payloads) uses `ChaChaPoly` via CryptoKit.

**Rationale:** Native, AEAD (authenticated encryption), consistent API. Nonce: 12 bytes random per encryption operation.

**Alternatives considered:** AES-GCM — equally native; ChaChaPoly chosen as default.

### 4. On-disk layout

```
vault/
├── vault.meta          # vault header (binary)
└── notes/
    └── <uuid>.note     # per-note file (binary)
```

`index.json` is app-maintained cache, rebuildable from `.note` plaintext headers.

### 5. Binary format: length-prefixed fields

Both `vault.meta` and `.note` use magic bytes + version + length-prefixed fields. No JSON in outer envelope (only inside encrypted payload).

**Rationale:** Explicit, compact, unambiguous parsing. Crypto package owns format helpers; app writes assembled bytes to disk.

### 6. Lower-level API (option B)

Crypto module exposes:
- KDF: `derivePasswordKey`, `deriveRecoveryKey`
- Keys: `wrapKey`, `unwrapKey`, `generateSymmetricKey`
- Cipher: `encrypt`, `decrypt`
- Format: `VaultHeader` serialize/parse, `NoteMetadata` parse, note crypto-section helpers

App responsibility: UUID generation, file I/O, index maintenance, UI.

### 7. Plaintext metadata in `.note` header

Fields stored unencrypted: `note_id`, `title`, `created_at`, `updated_at`, `attachment_count`, `attachments_total_size`.

**Rationale:** Enables note list UI without unlock. User accepts metadata leakage (titles visible on disk).

**Trade-off:** Attacker with filesystem access sees note titles and dates, not content.

### 8. Salt handling on password change

Salt is per-vault, stored in `vault.meta`. On password change, salt MAY be rotated (new random salt + re-wrap UDK) or kept (re-wrap only). v1: keep same salt for simplicity; rotation is optional enhancement.

Salt change affects only the vault it belongs to — no cross-vault impact.

### 9. BIP39 recovery

- 128-bit entropy → 12 English words (standard BIP39)
- Checksum validation on mnemonic entry
- Recovery phrase shown once at vault creation; never stored in plaintext
- `wrapped_udk_recovery` written to `vault.meta` at creation alongside password wrap

### 10. Encrypted payload format

JSON inside ChaChaPoly ciphertext:

```json
{
  "body": "<base64 or raw bytes>",
  "attachments": [
    { "id": "<uuid>", "filename": "...", "mime": "...", "data": "<bytes>" }
  ]
}
```

Swift `Codable` for serialization. Crypto module encrypts/decrypts the JSON `Data`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Plaintext titles leak metadata | Documented threat model; user accepts for UX |
| Plaintext `index.json` tamperable | v1 accepted; `.note` is source of truth, index rebuildable |
| Large attachments loaded entirely in memory | v1 embed in payload; app enforces size cap; streaming deferred |
| PBKDF2 slower than Argon2 on GPUs | 600k+ iterations + strong password guidance; sufficient for personal notes |
| Swift memory not zeroed on lock | Out of scope; auth module clears session keys on lock |
| No password recovery without mnemonic | By design; 12-word phrase is only recovery path |
| Format version drift | Magic + version byte in all blobs; migration helpers in future changes |

## Migration Plan

Greenfield — no migration. Package added to Xcode project as local Swift Package dependency. Future format versions bump `version` byte and add migration helpers in SecureCrypto.

## Open Questions

None — all decisions resolved during exploration.
