## Why

The `SecureCrypto` package currently mixes protocol definitions, shared types, concrete implementations, and the BIP39 wordlist resource in a single module. Feature modules that only need crypto contracts (e.g. vault lifecycle, note format) are forced to depend on the full implementation, making testing harder and coupling future features to PBKDF2, HKDF, and ChaChaPoly details they do not need.

Splitting protocols and the BIP39 wordlist into a dedicated `SecureCryptoProtocol` module lets feature code depend on abstractions only, while `SecureCrypto` remains the default concrete implementation.

## What Changes

- Add a new Swift Package target/product `SecureCryptoProtocol` alongside the existing `SecureCrypto` target
- Move crypto protocols (`PasswordKeyDeriving`, `RecoveryKeyDeriving`) into `SecureCryptoProtocol`
- Move shared contract types (`SecureCryptoError`, `ByteBuffer`) into `SecureCryptoProtocol`
- Move the BIP39 English wordlist resource (`english.txt`) and wordlist access API into `SecureCryptoProtocol`
- Introduce protocol abstractions for remaining public crypto operations currently exposed as free functions (`SymmetricCipher`, `KeyWrapping`, `SymmetricKeyGenerating`, `MnemonicValidating` / `MnemonicEncoding`) so feature modules never import concrete cipher/KDF code
- Update `SecureCrypto` to depend on `SecureCryptoProtocol` and house only concrete implementations
- Update tests: protocol contract tests in `SecureCryptoProtocolTests` (where applicable), implementation tests remain in `SecureCryptoTests`
- Update app/Xcode project to link both products where needed

## Capabilities

### New Capabilities

- `secure-crypto-protocol`: Module boundary and public contracts for crypto abstractions — KDF protocols, cipher/wrap/keygen/mnemonic protocols, shared error and buffer types, and the BIP39 English wordlist resource

### Modified Capabilities

- `secure-crypto`: Requirements unchanged; module layout updated so primitives are implemented in `SecureCrypto` against protocols defined in `SecureCryptoProtocol`. Spec scenarios remain the same — only the dependency graph and file locations change.

## Impact

- `Packages/SecureCrypto/Package.swift` — new target, product, and dependency edge
- `Packages/SecureCrypto/Sources/` — split into `SecureCryptoProtocol/` and `SecureCrypto/` directories
- All existing public API surface preserved (re-exported from `SecureCrypto` where needed to avoid **BREAKING** app imports during transition)
- Future feature modules (`vault-lifecycle`, `note-format`, app layer) should depend on `SecureCryptoProtocol` only; wire `SecureCrypto` at the composition root
- No change to cryptographic behavior, algorithms, or on-disk formats
