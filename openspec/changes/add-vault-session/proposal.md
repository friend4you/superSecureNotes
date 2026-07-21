## Why

`SecureCrypto` unlocks vaults statelessly — it derives keys and returns them to the caller, but nothing in the app owns in-memory key lifecycle between unlock and lock. A dedicated session package gives the auth module a single place to store UDK and identity private key after authentication, and gives feature modules (notes, sharing) a stable read API. Navigation and other UI can observe session activity without coupling to crypto or auth details.

## What Changes

- Add a new Swift Package `VaultSession` with two targets: `VaultSessionProtocol` (contracts) and `VaultSession` (default actor implementation)
- Define `VaultSession` protocol: `establish`, `clear`, key accessors, `isActive`, and `changes: AsyncStream<Bool>`
- Store only cryptographic keys in memory: UDK (`SymmetricKey`) and identity private key (`Data`, 32 bytes)
- Auth module is the sole writer (`establish` / `clear`); feature modules read keys; app/router observes `changes`
- Session does not perform unlock, password handling, biometrics, Keychain, vault file I/O, or navigation
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `vault-session`: In-memory vault key session — establish/clear lifecycle, key storage and access, activity observation via `AsyncStream<Bool>`, `VaultSessionError.notActive` on read when empty

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/VaultSession/` — new package (protocol target + actor implementation + tests)
- `superSecureNotes.xcodeproj` — link `VaultSession` and `VaultSessionProtocol` products
- Future auth module depends on `VaultSessionProtocol`; wires `VaultSession` at composition root
- No changes to `SecureCrypto` behavior or on-disk formats
- Out of scope: auth/unlock flows, biometrics, Keychain, lock timers, navigation, `vault.meta` persistence
