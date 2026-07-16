## Why

superSecureNotes needs a foundation for encrypting note content with a user master password before any app features can be built. A dedicated, testable crypto module isolates key derivation, envelope encryption, and on-disk formats from UI and auth concerns, enabling secure offline storage from day one.

## What Changes

- Add a local Swift Package `SecureCrypto` (iOS 17+, CryptoKit + CommonCrypto)
- Implement a key hierarchy: password or recovery phrase → KEK → UDK → per-note FEK
- Provide lower-level encrypt/decrypt and wrap/unwrap APIs (app assembles `.note` files)
- Define binary `vault.meta` format with per-vault salt and dual UDK wraps (password + recovery)
- Define binary `.note` format with length-prefixed plaintext metadata and encrypted JSON payload
- Support vault creation, password unlock, BIP39 recovery (12 English words), and password change (re-wrap UDK only)
- Expose `NoteMetadata` parser to read plaintext note headers without decryption

## Capabilities

### New Capabilities

- `secure-crypto`: Core cryptographic primitives — KDF protocols, ChaChaPoly cipher, key wrapping, vault header serialization
- `vault-lifecycle`: Vault creation, unlock (password), recovery (mnemonic), and password change flows
- `note-format`: Per-note file format, encrypted payload schema, and plaintext metadata parsing

### Modified Capabilities

<!-- None — greenfield project -->

## Impact

- New package at `Packages/SecureCrypto/`
- No changes to existing app UI code until integration phase
- Dependencies: Apple CryptoKit (iOS 17+), CommonCrypto (PBKDF2)
- Out of scope: auth/biometrics, Keychain, lock timing, note deletion, tags, `index.json` management, attachment size limits
