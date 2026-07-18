## 1. Package Structure

- [x] 1.1 Add `SecureCryptoProtocol` target and product to `Package.swift`; add `SecureCryptoProtocolTests` test target
- [x] 1.2 Create `Sources/SecureCryptoProtocol/` directory and scaffold empty module entry point
- [x] 1.3 Update `SecureCrypto` target to depend on `SecureCryptoProtocol`

## 2. Shared Contract Types

- [x] 2.1 Write failing tests: `SecureCryptoError` cases are `Equatable` and provide `LocalizedError` descriptions (`SecureCryptoProtocolTests/SecureCryptoErrorTests.swift`)
- [x] 2.2 Move `SecureCryptoError.swift` to `SecureCryptoProtocol`; make tests pass
- [x] 2.3 Write failing tests: `ByteBuffer` length-prefixed read/write roundtrip and insufficient-data error (`SecureCryptoProtocolTests/ByteBufferTests.swift`)
- [x] 2.4 Move `ByteBuffer.swift` to `SecureCryptoProtocol`; make tests pass

## 3. KDF Protocols

- [x] 3.1 Write failing tests: `PasswordKeyDeriving` protocol compiles with required properties and methods; mock conforming type satisfies contract (`SecureCryptoProtocolTests/PasswordKeyDerivingTests.swift`)
- [x] 3.2 Move `PasswordKeyDeriving` protocol definition to `SecureCryptoProtocol/PasswordKeyDeriving.swift`; keep `PBKDF2KeyDeriver` in `SecureCrypto`
- [x] 3.3 Write failing tests: `RecoveryKeyDeriving` protocol compiles with required method; mock conforming type satisfies contract (`SecureCryptoProtocolTests/RecoveryKeyDerivingTests.swift`)
- [x] 3.4 Move `RecoveryKeyDeriving` protocol definition to `SecureCryptoProtocol/RecoveryKeyDeriving.swift`; keep `HKDFRecoveryKeyDeriver` in `SecureCrypto`
- [x] 3.5 Verify existing `PBKDF2KeyDeriver` and `HKDFRecoveryKeyDeriver` tests still pass after import changes

## 4. Cipher, Wrap, and Keygen Protocols

- [x] 4.1 Write failing tests: `SymmetricCipher` protocol contract — mock encrypt/decrypt roundtrip (`SecureCryptoProtocolTests/SymmetricCipherTests.swift`)
- [x] 4.2 Add `SymmetricCipher` protocol to `SecureCryptoProtocol/SymmetricCipher.swift`
- [x] 4.3 Write failing tests: `ChaChaPolyCipher` conforms to `SymmetricCipher`; encrypt/decrypt roundtrip and tamper rejection (`SecureCryptoTests/ChaChaPolyCipherTests.swift` — update existing)
- [x] 4.4 Refactor `ChaChaPolyCipher.swift` — struct conforming to `SymmetricCipher`; keep free-function wrappers
- [x] 4.5 Write failing tests: `KeyWrapping` protocol contract — mock wrap/unwrap roundtrip (`SecureCryptoProtocolTests/KeyWrappingTests.swift`)
- [x] 4.6 Add `KeyWrapping` protocol to `SecureCryptoProtocol/KeyWrapping.swift`
- [x] 4.7 Write failing tests: `ChaChaPolyKeyWrapper` conforms to `KeyWrapping`; wrap/unwrap roundtrip and wrong-key failure (`SecureCryptoTests/KeyWrappingTests.swift` — update existing)
- [x] 4.8 Refactor `KeyWrapping.swift` — struct conforming to `KeyWrapping`; keep free-function wrappers
- [x] 4.9 Write failing tests: `SymmetricKeyGenerating` protocol contract — mock returns 256-bit key (`SecureCryptoProtocolTests/SymmetricKeyGeneratingTests.swift`)
- [x] 4.10 Add `SymmetricKeyGenerating` protocol to `SecureCryptoProtocol/SymmetricKeyGenerating.swift`
- [x] 4.11 Write failing tests: `CryptoKitKeyGenerator` conforms to `SymmetricKeyGenerating`; returns 256-bit key (`SecureCryptoTests/SymmetricKeyGenerationTests.swift` — update existing)
- [x] 4.12 Refactor `SymmetricKeyGeneration.swift` — struct conforming to `SymmetricKeyGenerating`; keep free-function wrapper

## 5. BIP39 Wordlist and Mnemonic Protocol

- [x] 5.1 Move `Resources/english.txt` to `SecureCryptoProtocol/Resources/`
- [x] 5.2 Write failing tests: `BIP39Wordlist` loads 2048 words from bundle; `index(of:)` returns nil for unknown word (`SecureCryptoProtocolTests/BIP39WordlistTests.swift`)
- [x] 5.3 Move and publicize `BIP39Wordlist.swift` in `SecureCryptoProtocol`; make tests pass
- [x] 5.4 Write failing tests: `MnemonicEncoding` protocol contract — mock words/validate/entropy methods (`SecureCryptoProtocolTests/MnemonicEncodingTests.swift`)
- [x] 5.5 Add `MnemonicEncoding` protocol to `SecureCryptoProtocol/MnemonicEncoding.swift`
- [x] 5.6 Write failing tests: `BIP39MnemonicEncoder` conforms to `MnemonicEncoding`; generation, validation, checksum rejection, wrong word count, entropy roundtrip (`SecureCryptoTests/BIP39MnemonicTests.swift` — update existing)
- [x] 5.7 Refactor `BIP39Mnemonic.swift` — extract `BIP39MnemonicEncoder` struct; keep `BIP39Mnemonic` enum as convenience facade delegating to default encoder

## 6. Module Integration and Backward Compatibility

- [x] 6.1 Add `@_exported import SecureCryptoProtocol` to `SecureCrypto` module entry point
- [x] 6.2 Verify all existing `SecureCryptoTests` pass without modification to test logic (imports only)
- [x] 6.3 Verify `SecureCryptoProtocol` builds with no CommonCrypto dependency
- [x] 6.4 Update Xcode project to expose `SecureCryptoProtocol` product if not auto-discovered

## 7. Documentation

- [x] 7.1 Add module dependency diagram and import guidance to `Packages/SecureCrypto/README.md` (feature modules → `SecureCryptoProtocol`; app composition root → `SecureCrypto`)
