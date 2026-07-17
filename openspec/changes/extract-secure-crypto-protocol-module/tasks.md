## 1. Package Structure

- [ ] 1.1 Add `SecureCryptoProtocol` target and product to `Package.swift`; add `SecureCryptoProtocolTests` test target
- [ ] 1.2 Create `Sources/SecureCryptoProtocol/` directory and scaffold empty module entry point
- [ ] 1.3 Update `SecureCrypto` target to depend on `SecureCryptoProtocol`

## 2. Shared Contract Types

- [ ] 2.1 Write failing tests: `SecureCryptoError` cases are `Equatable` and provide `LocalizedError` descriptions (`SecureCryptoProtocolTests/SecureCryptoErrorTests.swift`)
- [ ] 2.2 Move `SecureCryptoError.swift` to `SecureCryptoProtocol`; make tests pass
- [ ] 2.3 Write failing tests: `ByteBuffer` length-prefixed read/write roundtrip and insufficient-data error (`SecureCryptoProtocolTests/ByteBufferTests.swift`)
- [ ] 2.4 Move `ByteBuffer.swift` to `SecureCryptoProtocol`; make tests pass

## 3. KDF Protocols

- [ ] 3.1 Write failing tests: `PasswordKeyDeriving` protocol compiles with required properties and methods; mock conforming type satisfies contract (`SecureCryptoProtocolTests/PasswordKeyDerivingTests.swift`)
- [ ] 3.2 Move `PasswordKeyDeriving` protocol definition to `SecureCryptoProtocol/PasswordKeyDeriving.swift`; keep `PBKDF2KeyDeriver` in `SecureCrypto`
- [ ] 3.3 Write failing tests: `RecoveryKeyDeriving` protocol compiles with required method; mock conforming type satisfies contract (`SecureCryptoProtocolTests/RecoveryKeyDerivingTests.swift`)
- [ ] 3.4 Move `RecoveryKeyDeriving` protocol definition to `SecureCryptoProtocol/RecoveryKeyDeriving.swift`; keep `HKDFRecoveryKeyDeriver` in `SecureCrypto`
- [ ] 3.5 Verify existing `PBKDF2KeyDeriver` and `HKDFRecoveryKeyDeriver` tests still pass after import changes

## 4. Cipher, Wrap, and Keygen Protocols

- [ ] 4.1 Write failing tests: `SymmetricCipher` protocol contract — mock encrypt/decrypt roundtrip (`SecureCryptoProtocolTests/SymmetricCipherTests.swift`)
- [ ] 4.2 Add `SymmetricCipher` protocol to `SecureCryptoProtocol/SymmetricCipher.swift`
- [ ] 4.3 Write failing tests: `ChaChaPolyCipher` conforms to `SymmetricCipher`; encrypt/decrypt roundtrip and tamper rejection (`SecureCryptoTests/ChaChaPolyCipherTests.swift` — update existing)
- [ ] 4.4 Refactor `ChaChaPolyCipher.swift` — struct conforming to `SymmetricCipher`; keep free-function wrappers
- [ ] 4.5 Write failing tests: `KeyWrapping` protocol contract — mock wrap/unwrap roundtrip (`SecureCryptoProtocolTests/KeyWrappingTests.swift`)
- [ ] 4.6 Add `KeyWrapping` protocol to `SecureCryptoProtocol/KeyWrapping.swift`
- [ ] 4.7 Write failing tests: `ChaChaPolyKeyWrapper` conforms to `KeyWrapping`; wrap/unwrap roundtrip and wrong-key failure (`SecureCryptoTests/KeyWrappingTests.swift` — update existing)
- [ ] 4.8 Refactor `KeyWrapping.swift` — struct conforming to `KeyWrapping`; keep free-function wrappers
- [ ] 4.9 Write failing tests: `SymmetricKeyGenerating` protocol contract — mock returns 256-bit key (`SecureCryptoProtocolTests/SymmetricKeyGeneratingTests.swift`)
- [ ] 4.10 Add `SymmetricKeyGenerating` protocol to `SecureCryptoProtocol/SymmetricKeyGenerating.swift`
- [ ] 4.11 Write failing tests: `CryptoKitKeyGenerator` conforms to `SymmetricKeyGenerating`; returns 256-bit key (`SecureCryptoTests/SymmetricKeyGenerationTests.swift` — update existing)
- [ ] 4.12 Refactor `SymmetricKeyGeneration.swift` — struct conforming to `SymmetricKeyGenerating`; keep free-function wrapper

## 5. BIP39 Wordlist and Mnemonic Protocol

- [ ] 5.1 Move `Resources/english.txt` to `SecureCryptoProtocol/Resources/`
- [ ] 5.2 Write failing tests: `BIP39Wordlist` loads 2048 words from bundle; `index(of:)` returns nil for unknown word (`SecureCryptoProtocolTests/BIP39WordlistTests.swift`)
- [ ] 5.3 Move and publicize `BIP39Wordlist.swift` in `SecureCryptoProtocol`; make tests pass
- [ ] 5.4 Write failing tests: `MnemonicEncoding` protocol contract — mock words/validate/entropy methods (`SecureCryptoProtocolTests/MnemonicEncodingTests.swift`)
- [ ] 5.5 Add `MnemonicEncoding` protocol to `SecureCryptoProtocol/MnemonicEncoding.swift`
- [ ] 5.6 Write failing tests: `BIP39MnemonicEncoder` conforms to `MnemonicEncoding`; generation, validation, checksum rejection, wrong word count, entropy roundtrip (`SecureCryptoTests/BIP39MnemonicTests.swift` — update existing)
- [ ] 5.7 Refactor `BIP39Mnemonic.swift` — extract `BIP39MnemonicEncoder` struct; keep `BIP39Mnemonic` enum as convenience facade delegating to default encoder

## 6. Module Integration and Backward Compatibility

- [ ] 6.1 Add `@_exported import SecureCryptoProtocol` to `SecureCrypto` module entry point
- [ ] 6.2 Verify all existing `SecureCryptoTests` pass without modification to test logic (imports only)
- [ ] 6.3 Verify `SecureCryptoProtocol` builds with no CommonCrypto dependency
- [ ] 6.4 Update Xcode project to expose `SecureCryptoProtocol` product if not auto-discovered

## 7. Documentation

- [ ] 7.1 Add module dependency diagram and import guidance to `Packages/SecureCrypto/README.md` (feature modules → `SecureCryptoProtocol`; app composition root → `SecureCrypto`)
