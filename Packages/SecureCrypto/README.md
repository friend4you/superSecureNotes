# SecureCrypto

Swift package providing cryptographic primitives for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── SecureCryptoProtocol   ← feature modules should depend on this
    └── SecureCrypto           ← composition root / default implementations

SecureCrypto
    └── SecureCryptoProtocol

SecureCryptoProtocol
    └── CryptoKit (type references only)
```

### Source folders

```
Sources/SecureCrypto/
├── Core/           SecureCrypto.swift (re-export)
├── Symmetric/      ChaChaPoly, key wrapping, symmetric key generation
├── KDF/            PBKDF2, HKDF
├── Identity/       Curve25519 key pair, UDK identity wrap/unwrap
├── Mnemonic/       BIP39 mnemonic encoding
├── Vault/          vault.meta format, lifecycle (create/unlock/recover)
└── Note/           .note format, payload encryption

Sources/SecureCryptoProtocol/
├── Protocols/      crypto abstraction protocols
├── Shared/         ByteBuffer, SecureCryptoError
└── Mnemonic/       BIP39Wordlist + english.txt resource

Tests/ mirror the same domain folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| Feature modules (vault lifecycle, note format, UI validation) | `SecureCryptoProtocol` | Protocols, shared errors, `ByteBuffer`, and BIP39 wordlist — no PBKDF2 or ChaChaPoly implementations |
| App composition root | `SecureCrypto` | Default implementations (`PBKDF2KeyDeriver`, `ChaChaPolyCipher`, `BIP39MnemonicEncoder`, etc.) |

`SecureCrypto` re-exports `SecureCryptoProtocol` via `@_exported import`, so existing `import SecureCrypto` call sites continue to work. New feature code should import `SecureCryptoProtocol` directly to keep dependencies explicit.

## Products

- **SecureCryptoProtocol** — crypto contracts, `SecureCryptoError`, `ByteBuffer`, `BIP39Wordlist`
- **SecureCrypto** — concrete implementations and convenience wrappers

## Testing

```bash
swift test --package-path Packages/SecureCrypto
```

Protocol contract tests live in `SecureCryptoProtocolTests`; algorithm and roundtrip tests live in `SecureCryptoTests`.
