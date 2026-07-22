## 1. Package Structure

- [x] 1.1 Create `Packages/VaultSession/Package.swift` with `VaultSessionProtocol` and `VaultSession` targets/products and test targets (platforms: iOS 17+, macOS 13+)
- [x] 1.2 Scaffold `Sources/VaultSessionProtocol/` and `Sources/VaultSession/` module entry points
- [x] 1.3 Add `VaultSession` package dependency to Xcode project

## 2. Shared Contract Types

- [x] 2.1 Write failing tests: `VaultSessionError.notActive` is `Equatable` and `Sendable` (`VaultSessionProtocolTests/VaultSessionErrorTests.swift`)
- [x] 2.2 Add `VaultSessionError` to `VaultSessionProtocol`; make tests pass
- [x] 2.3 Write failing tests: `VaultSessionKeys` holds `SymmetricKey` UDK and 32-byte `identityPrivateKey`; conforms to `Sendable` and `Equatable` (`VaultSessionProtocolTests/VaultSessionKeysTests.swift`)
- [x] 2.4 Add `VaultSessionKeys` to `VaultSessionProtocol`; make tests pass

## 3. VaultSession Protocol

- [x] 3.1 Write failing tests: `VaultSession` protocol compiles with `isActive`, `changes`, `establish`, `clear`, `udk()`, and `identityPrivateKey()`; mock actor type satisfies contract (`VaultSessionProtocolTests/VaultSessionTests.swift`)
- [x] 3.2 Add `VaultSession` protocol definition to `VaultSessionProtocol/VaultSession.swift`

## 4. Actor Implementation — Lifecycle

- [x] 4.1 Write failing tests: new session `isActive` is false; `establish` sets active; `clear` sets inactive; idempotent `clear` (`VaultSessionTests/VaultSessionLifecycleTests.swift`)
- [x] 4.2 Implement `actor VaultSession` with `establish`, `clear`, and `isActive`; make lifecycle tests pass
- [x] 4.3 Write failing tests: `establish` while active replaces keys with new values (`VaultSessionTests/VaultSessionLifecycleTests.swift`)
- [x] 4.4 Update `establish` to overwrite existing keys; make tests pass

## 5. Actor Implementation — Key Access

- [x] 5.1 Write failing tests: `udk()` and `identityPrivateKey()` return established values when active; throw `VaultSessionError.notActive` when inactive (`VaultSessionTests/VaultSessionKeyAccessTests.swift`)
- [x] 5.2 Implement `udk()` and `identityPrivateKey()`; make tests pass

## 6. Actor Implementation — Observation

- [x] 6.1 Write failing tests: `changes` yields `true` on `establish`, `false` on `clear`; new subscriber gets current `isActive` immediately; idempotent `clear` does not emit (`VaultSessionTests/VaultSessionObservationTests.swift`)
- [x] 6.2 Implement `changes: AsyncStream<Bool>` with initial yield and mutation emissions; make tests pass

## 7. Module Integration

- [x] 7.1 Add `@_exported import VaultSessionProtocol` to `VaultSession` module entry point
- [x] 7.2 Verify all `VaultSessionProtocolTests` and `VaultSessionTests` pass
- [x] 7.3 Add `Packages/VaultSession/README.md` with module dependency diagram and import guidance (feature modules → `VaultSessionProtocol`; composition root → `VaultSession`)
