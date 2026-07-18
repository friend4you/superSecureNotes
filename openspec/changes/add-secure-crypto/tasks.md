## 1. Package Setup

- [x] 1.1 Create `Packages/SecureCrypto/` Swift Package with iOS 17+ deployment target
- [x] 1.2 Add package to Xcode project as local dependency
- [x] 1.3 Define shared error types (`SecureCryptoError`) and byte buffer utilities

## 2. Core Crypto Primitives

- [x] 2.1 Write failing tests: PBKDF2 derivation with known test vectors
- [x] 2.2 Implement `PasswordKeyDeriving` protocol and `PBKDF2KeyDeriver` (CommonCrypto, 600k iterations, SHA256)
- [x] 2.3 Write failing tests: HKDF recovery key derivation from 128-bit entropy
- [x] 2.4 Implement `RecoveryKeyDeriving` protocol and `HKDFRecoveryKeyDeriver` (CryptoKit)
- [x] 2.5 Write failing tests: ChaChaPoly encrypt/decrypt roundtrip and tamper rejection
- [x] 2.6 Implement ChaChaPoly `encrypt`/`decrypt` helpers with random 12-byte nonce
- [x] 2.7 Write failing tests: key wrap/unwrap roundtrip and wrong-key failure
- [x] 2.8 Implement `wrapKey`/`unwrapKey` for 256-bit key envelope encryption
- [x] 2.9 Write failing tests: `generateSymmetricKey()` returns 256-bit key with full entropy
- [x] 2.10 Implement `generateSymmetricKey()` using secure random bytes

## 3. BIP39 Mnemonic

- [x] 3.1 Bundle English BIP39 wordlist (2048 words)
- [x] 3.2 Write failing tests: mnemonic generation produces 12 valid English words from 128-bit entropy
- [x] 3.3 Implement mnemonic generation from 128-bit entropy (12 words)
- [x] 3.4 Write failing tests: mnemonic validation accepts valid phrase, rejects bad checksum and wrong word count
- [x] 3.5 Implement mnemonic validation with checksum verification
- [x] 3.6 Write failing tests: mnemonic-to-entropy decoding roundtrip
- [x] 3.7 Implement mnemonic-to-entropy decoding

## 4. Vault Header Format

- [x] 4.1 Define `VaultHeader` model (salt, kdf params, both wrapped UDK blobs)
- [x] 4.2 Write failing tests: vault header serialize → deserialize roundtrip
- [x] 4.3 Implement binary serialization (magic `SSNV`, version, length-prefixed fields)
- [x] 4.4 Write failing tests: vault header rejects invalid magic and unsupported version
- [x] 4.5 Implement binary deserialization with magic/version validation

## 5. Vault Lifecycle

- [x] 5.1 Write failing tests: vault create → unlock (password) → recover (mnemonic) → same UDK
- [x] 5.2 Implement `createVault(password:)` — generate UDK, mnemonic, both wraps, return header + phrase
- [x] 5.3 Implement `unlockVault(header:password:)` — derive KEK, unwrap password wrap, return UDK
- [x] 5.4 Implement `recoverVault(header:mnemonic:)` — validate phrase, derive recovery KEK, unwrap, return UDK
- [x] 5.5 Write failing tests: password change preserves UDK and note decryptability; wrong old password rejected
- [ ] 5.6 Implement `changePassword(header:oldPassword:newPassword:)` — re-wrap UDK, return updated header

## 6. Note File Format

- [ ] 6.1 Define `NoteMetadata` model (note_id, title, created_at, updated_at, attachment_count, attachments_total_size)
- [ ] 6.2 Define `NotePayload` Codable model (body, attachments array)
- [ ] 6.3 Write failing tests: plaintext metadata serialize → parse roundtrip via `NoteMetadata.fromNoteFile`
- [ ] 6.4 Implement plaintext metadata serialization (length-prefixed binary, magic `SSNT`)
- [ ] 6.5 Implement `NoteMetadata.fromNoteFile(data:)` parser (no decryption required)
- [ ] 6.6 Write failing tests: note file assembly → section parser roundtrip
- [ ] 6.7 Implement note file assembly helper (metadata + wrapped FEK + encrypted payload → `.note` bytes)
- [ ] 6.8 Write failing tests: note file rejects invalid magic and unsupported version
- [ ] 6.9 Implement note file section parser (split blob into metadata, wrapped FEK, encrypted payload)

## 7. Note Encryption Helpers

- [ ] 7.1 Write failing tests: FEK wrap/unwrap roundtrip with UDK
- [ ] 7.2 Implement `wrapFEK(fek:udk:)` and `unwrapFEK(wrappedFek:udk:)`
- [ ] 7.3 Write failing tests: payload encrypt → decrypt roundtrip with JSON body and attachments
- [ ] 7.4 Implement `encryptPayload(_:fek:)` — JSON encode + ChaChaPoly encrypt
- [ ] 7.5 Implement `decryptPayload(_:fek:)` — ChaChaPoly decrypt + JSON decode
