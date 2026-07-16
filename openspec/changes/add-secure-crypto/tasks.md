## 1. Package Setup

- [ ] 1.1 Create `Packages/SecureCrypto/` Swift Package with iOS 17+ deployment target
- [ ] 1.2 Add package to Xcode project as local dependency
- [ ] 1.3 Define shared error types (`SecureCryptoError`) and byte buffer utilities

## 2. Core Crypto Primitives

- [ ] 2.1 Implement `PasswordKeyDeriving` protocol and `PBKDF2KeyDeriver` (CommonCrypto, 600k iterations, SHA256)
- [ ] 2.2 Implement `RecoveryKeyDeriving` protocol and `HKDFRecoveryKeyDeriver` (CryptoKit)
- [ ] 2.3 Implement ChaChaPoly `encrypt`/`decrypt` helpers with random 12-byte nonce
- [ ] 2.4 Implement `wrapKey`/`unwrapKey` for 256-bit key envelope encryption
- [ ] 2.5 Implement `generateSymmetricKey()` using secure random bytes

## 3. BIP39 Mnemonic

- [ ] 3.1 Bundle English BIP39 wordlist (2048 words)
- [ ] 3.2 Implement mnemonic generation from 128-bit entropy (12 words)
- [ ] 3.3 Implement mnemonic validation with checksum verification
- [ ] 3.4 Implement mnemonic-to-entropy decoding

## 4. Vault Header Format

- [ ] 4.1 Define `VaultHeader` model (salt, kdf params, both wrapped UDK blobs)
- [ ] 4.2 Implement binary serialization (magic `SSNV`, version, length-prefixed fields)
- [ ] 4.3 Implement binary deserialization with magic/version validation

## 5. Vault Lifecycle

- [ ] 5.1 Implement `createVault(password:)` — generate UDK, mnemonic, both wraps, return header + phrase
- [ ] 5.2 Implement `unlockVault(header:password:)` — derive KEK, unwrap password wrap, return UDK
- [ ] 5.3 Implement `recoverVault(header:mnemonic:)` — validate phrase, derive recovery KEK, unwrap, return UDK
- [ ] 5.4 Implement `changePassword(header:oldPassword:newPassword:)` — re-wrap UDK, return updated header

## 6. Note File Format

- [ ] 6.1 Define `NoteMetadata` model (note_id, title, created_at, updated_at, attachment_count, attachments_total_size)
- [ ] 6.2 Define `NotePayload` Codable model (body, attachments array)
- [ ] 6.3 Implement plaintext metadata serialization (length-prefixed binary, magic `SSNT`)
- [ ] 6.4 Implement `NoteMetadata.fromNoteFile(data:)` parser (no decryption required)
- [ ] 6.5 Implement note file assembly helper (metadata + wrapped FEK + encrypted payload → `.note` bytes)
- [ ] 6.6 Implement note file section parser (split blob into metadata, wrapped FEK, encrypted payload)

## 7. Note Encryption Helpers

- [ ] 7.1 Implement `wrapFEK(fek:udk:)` and `unwrapFEK(wrappedFek:udk:)`
- [ ] 7.2 Implement `encryptPayload(_:fek:)` — JSON encode + ChaChaPoly encrypt
- [ ] 7.3 Implement `decryptPayload(_:fek:)` — ChaChaPoly decrypt + JSON decode

## 8. Tests

- [ ] 8.1 Unit tests: PBKDF2 derivation with known test vectors
- [ ] 8.2 Unit tests: ChaChaPoly encrypt/decrypt roundtrip and tamper rejection
- [ ] 8.3 Unit tests: key wrap/unwrap roundtrip and wrong-key failure
- [ ] 8.4 Unit tests: BIP39 generate, validate, reject bad checksum/word count
- [ ] 8.5 Unit tests: vault create → unlock (password) → recover (mnemonic) → same UDK
- [ ] 8.6 Unit tests: password change preserves UDK and note decryptability
- [ ] 8.7 Unit tests: note file serialize → parse metadata → encrypt/decrypt payload roundtrip
- [ ] 8.8 Unit tests: vault header and note file reject invalid magic/version
