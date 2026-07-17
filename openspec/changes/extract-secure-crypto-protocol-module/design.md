## Context

The `SecureCrypto` Swift Package currently contains protocols, shared types, concrete implementations, and the BIP39 wordlist in a single target. Vault lifecycle and note-format features (planned) need crypto contracts for dependency injection and testing but should not pull in PBKDF2 (CommonCrypto) or ChaChaPoly implementation details.

The original `add-secure-crypto` design intentionally deferred cipher/wrap protocol abstraction ("concrete ChaChaPoly only in v1"). This change revisits that decision as part of the module split so feature modules never depend on implementation code.

Current layout:

```
Packages/SecureCrypto/
├── Package.swift
├── Sources/SecureCrypto/          # everything in one target today
│   ├── PasswordKeyDeriving.swift  # protocol + PBKDF2KeyDeriver
│   ├── RecoveryKeyDeriving.swift  # protocol + HKDFRecoveryKeyDeriver
│   ├── ChaChaPolyCipher.swift     # free functions
│   ├── KeyWrapping.swift          # free functions
│   ├── SymmetricKeyGeneration.swift
│   ├── BIP39Mnemonic.swift
│   ├── BIP39Wordlist.swift        # internal, loads english.txt
│   ├── ByteBuffer.swift
│   ├── SecureCryptoError.swift
│   └── Resources/english.txt
└── Tests/SecureCryptoTests/
```

## Goals / Non-Goals

**Goals:**

- Introduce `SecureCryptoProtocol` as a separate SPM target/product with zero implementation dependencies (Foundation + CryptoKit for `SymmetricKey` only)
- Move all protocols and shared contract types into `SecureCryptoProtocol`
- Move BIP39 `english.txt` and `BIP39Wordlist` into `SecureCryptoProtocol` so word validation is available without importing implementations
- Add protocols for cipher, key wrapping, key generation, and mnemonic encoding (replacing free-function-only APIs for DI consumers)
- Keep `SecureCrypto` as the default implementation target depending on `SecureCryptoProtocol`
- Preserve existing public API via convenience wrappers/re-exports in `SecureCrypto` to avoid breaking current imports
- Maintain all existing test behavior; reorganize tests by module boundary

**Non-Goals:**

- Changing cryptographic algorithms, parameters, or on-disk formats
- Creating a separate package directory (both targets stay in `Packages/SecureCrypto/`)
- Migrating the app to use protocols yet (composition root wiring comes during feature integration)
- Protocol abstraction for `ByteBuffer` serialization (concrete struct is a shared contract, not an algorithm)
- Localization of error strings beyond current English hardcoding

## Decisions

### 1. Two targets in one package (not two packages)

```
Packages/SecureCrypto/
├── Package.swift
├── Sources/
│   ├── SecureCryptoProtocol/     # protocols, errors, ByteBuffer, BIP39Wordlist + english.txt
│   └── SecureCrypto/             # PBKDF2, HKDF, ChaChaPoly, BIP39MnemonicEncoder
└── Tests/
    ├── SecureCryptoProtocolTests/
    └── SecureCryptoTests/
```

**Rationale:** Keeps related code co-located, single version, simpler Xcode integration. Two products (`SecureCryptoProtocol`, `SecureCrypto`) are sufficient for dependency control.

**Alternatives considered:**
- Separate `Packages/SecureCryptoProtocol/` package — cleaner boundary but more Xcode wiring and version coordination; rejected for now

### 2. Protocol surface for all injectable crypto operations

| Protocol (SecureCryptoProtocol) | Default impl (SecureCrypto) | Replaces |
|----------------------------------|----------------------------|----------|
| `PasswordKeyDeriving` | `PBKDF2KeyDeriver` | existing protocol (moved) |
| `RecoveryKeyDeriving` | `HKDFRecoveryKeyDeriver` | existing protocol (moved) |
| `SymmetricCipher` | `ChaChaPolyCipher` | `encrypt`/`decrypt` free functions |
| `KeyWrapping` | `ChaChaPolyKeyWrapper` | `wrapKey`/`unwrapKey` free functions |
| `SymmetricKeyGenerating` | `CryptoKitKeyGenerator` | `generateSymmetricKey()` free function |
| `MnemonicEncoding` | `BIP39MnemonicEncoder` | `BIP39Mnemonic` enum static methods |

**Rationale:** Feature modules need to inject all crypto operations for testing. Free functions remain as thin convenience wrappers delegating to default struct instances to preserve backward compatibility.

**Alternatives considered:**
- Move only KDF protocols, keep cipher as free functions — rejected; user explicitly wants full protocol dependency boundary

### 3. BIP39 wordlist lives in protocol module

`english.txt` and `BIP39Wordlist` move to `SecureCryptoProtocol`. The wordlist is a shared contract resource (2048 valid words), not an algorithm. UI layers validating recovery phrase input can import `SecureCryptoProtocol` alone.

`BIP39MnemonicEncoder` in `SecureCrypto` implements `MnemonicEncoding` using `BIP39Wordlist` and CryptoKit `SHA256` for checksum.

### 4. CryptoKit dependency in protocol module

Protocols use `SymmetricKey` in signatures. `SecureCryptoProtocol` depends on CryptoKit for type references only — no encryption calls in the protocol target.

**Alternatives considered:**
- Abstract `SymmetricKey` behind a custom type — excessive indirection for no security gain; rejected

### 5. Backward-compatible API in SecureCrypto

Existing free functions (`encrypt`, `decrypt`, `wrapKey`, `unwrapKey`, `generateSymmetricKey`) and `BIP39Mnemonic` enum remain public in `SecureCrypto`, implemented as one-line delegations to default conforming types. No **BREAKING** change for code already importing `SecureCrypto`.

`@_exported import SecureCryptoProtocol` in `SecureCrypto` ensures consumers importing `SecureCrypto` still see protocol types.

### 6. Dependency graph

```
superSecureNotes (app)
    ├── SecureCryptoProtocol   (future feature code)
    └── SecureCrypto           (composition root / default impl)

SecureCrypto
    └── SecureCryptoProtocol

SecureCryptoProtocol
    └── CryptoKit (types only)
```

## Risks / Trade-offs

- **[Risk] Duplicate test coverage across modules** → Protocol module tests cover contracts and wordlist loading; implementation tests cover roundtrips and algorithm correctness. No scenario tested twice with different assertions.

- **[Risk] `@_exported import` hides explicit protocol dependency** → Document in README that feature code should `import SecureCryptoProtocol` directly; app composition root imports `SecureCrypto`.

- **[Risk] BIP39Wordlist becomes public API surface** → Keep lookup methods minimal (`word(at:)`, `index(of:)`, `wordCount`). No mutable state.

- **[Trade-off] More protocols to maintain** → Acceptable for testability; default structs are zero-cost wrappers.

## Migration Plan

1. Add `SecureCryptoProtocol` target to `Package.swift` (no consumers yet)
2. Move types and resource; verify `SecureCryptoProtocol` builds and tests pass
3. Add new protocols and default impl structs in `SecureCrypto`
4. Update `SecureCrypto` to depend on `SecureCryptoProtocol`; move implementations
5. Add `@_exported import` and convenience wrappers
6. Re-run full test suite; update Xcode project if product list changes
7. Rollback: revert to single-target layout (no on-disk format changes, safe to revert)

## Open Questions

- Should `vault-lifecycle` and `note-format` (when implemented) be separate packages that depend only on `SecureCryptoProtocol`? → Recommended yes, but out of scope for this change.
- Should `BIP39Mnemonic` enum move to `SecureCryptoProtocol` as a typealias to a protocol existential? → Keep as `SecureCrypto` convenience facade for now.
