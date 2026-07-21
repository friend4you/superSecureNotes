## Context

`SecureCrypto` provides stateless vault unlock: password or mnemonic in, UDK and upgraded header out. The identity private key is unwrapped separately via `unwrapIdentityPrivateKey(header:udk:)`. No app-layer module currently holds these keys in memory between unlock and lock.

OpenSpec design docs defer biometrics, Keychain, lock timing, and session key caching to a future **auth module**. This change introduces a separate **session module** that auth will write to after successful authentication. Feature modules (notes, sharing) read keys from session. Navigation observes session activity but does not live in this package.

The app target is still a placeholder; this is greenfield infrastructure following the same protocol/implementation split as `SecureCrypto` / `SecureCryptoProtocol`.

## Goals / Non-Goals

**Goals:**

- New Swift Package `Packages/VaultSession/` with `VaultSessionProtocol` and `VaultSession` targets
- `actor VaultSession` as default in-memory implementation
- Store only UDK (`SymmetricKey`) and identity private key (`Data`, 32 bytes) while session is active
- Expose `establish`, `clear`, `isActive`, key accessors, and `changes: AsyncStream<Bool>`
- Auth module is the sole writer (`establish` / `clear`); feature modules read; app observes `changes`
- CryptoKit-only dependency in `VaultSessionProtocol` (no `SecureCrypto` coupling)
- Strict TDD aligned with `development-practices` spec

**Non-Goals:**

- Password unlock, mnemonic recovery, biometrics, Keychain (auth module)
- Lock timers, background lock policy (auth module)
- Navigation, routing, SwiftUI (app layer)
- `vault.meta` load/save or header upgrade persistence (auth / storage layer)
- Storing passwords, mnemonics, or `VaultHeader` in session
- Secure memory zeroing on clear (documented limitation; same as SecureCrypto auth deferral)

## Decisions

### 1. Separate package (not a target inside SecureCrypto)

```
Packages/VaultSession/
├── Package.swift
├── Sources/
│   ├── VaultSessionProtocol/     # protocol, VaultSessionKeys, VaultSessionError
│   └── VaultSession/             # actor VaultSession
└── Tests/
    ├── VaultSessionProtocolTests/
    └── VaultSessionTests/
```

**Rationale:** Session is app infrastructure, not cryptography. Keeps `SecureCrypto` Keychain-free and crypto-pure. Auth will depend on both packages independently.

**Alternatives considered:**
- Target inside app — faster to start but harder to test in isolation; rejected
- Target inside SecureCrypto — blurs crypto vs session concerns; rejected

### 2. Single `VaultSession` protocol (read + write)

One protocol with `establish`, `clear`, `isActive`, key accessors, and `changes`. Auth is the only caller of mutating methods by convention; no separate reader/writer protocols in v1.

**Rationale:** Minimal surface for a two-operation lifecycle. Least privilege can be enforced at composition root (inject read-only facade later if needed).

### 3. `actor VaultSession` for thread-safe key storage

Implementation is a Swift `actor` conforming to `VaultSession` protocol.

**Rationale:** Keys are shared across async tasks; actor serializes access without manual locks. Aligns with Swift concurrency best practices.

**Alternatives considered:**
- `class` + `NSLock` — more boilerplate; rejected
- `@MainActor` — unnecessarily pins session to main thread; rejected

### 4. Session payload: keys only

```swift
public struct VaultSessionKeys: Sendable, Equatable {
    public let udk: SymmetricKey
    public let identityPrivateKey: Data  // 32 bytes
}
```

No `VaultHeader`, password, or mnemonic in session.

**Rationale:** Auth owns persistence and unlock orchestration. Session is a narrow key cache for the unlocked window. Password change re-wraps UDK in header but UDK bytes are unchanged — session stays valid without update.

### 5. `establish` replaces keys silently when already active

Calling `establish` when session is already active overwrites stored keys and emits `true` on `changes`.

**Rationale:** Simplifies auth re-auth flows; idempotent from observer perspective (still active). Tests need deterministic behavior.

**Alternatives considered:**
- Throw if already active — forces auth to clear first; unnecessary friction
- No-op if already active — hides auth bugs

### 6. Key access throws `VaultSessionError.notActive` when empty

`udk()` and `identityPrivateKey()` throw when no keys are stored. No optional return types.

**Rationale:** Callers must handle inactive session explicitly; matches `SecureCryptoError` throwing style.

### 7. Observation via `AsyncStream<Bool>` only

`changes` emits `true` when session becomes active (`establish`), `false` when cleared (`clear`). New subscribers receive the current `isActive` value immediately upon subscription (initial yield).

No callback-based `sessionDidChange` API in v1.

**Rationale:** Testable, supports multiple observers, no retain-cycle risk. App/router can `for await` or bridge to SwiftUI.

### 8. `clear` is idempotent

Calling `clear` when already inactive is a no-op and does not emit on `changes`.

**Rationale:** Auth may call lock defensively; avoids duplicate navigation events.

### 9. Dependency: CryptoKit only in protocol module

`VaultSessionProtocol` imports Foundation and CryptoKit (`SymmetricKey`). No `SecureCrypto` or `SecureCryptoProtocol` dependency.

**Rationale:** Session stores keys, not crypto operations. Auth bridges `SecureCrypto` unlock results into `VaultSessionKeys`.

### 10. Products and import guidance

| Consumer | Import |
|----------|--------|
| Auth module (future) | `VaultSessionProtocol` + `VaultSession` |
| Feature modules (notes, sharing) | `VaultSessionProtocol` only |
| App composition root | `VaultSession` (wire concrete actor) |

`VaultSession` target `@_exported import VaultSessionProtocol` for convenience at composition root (mirror `SecureCrypto` pattern).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Swift does not zero memory on `clear` | Document limitation; auth module owns lock policy; same as existing SecureCrypto deferral |
| Single protocol allows accidental `clear` from feature code | Convention + composition root; only inject session to auth for writes in v1 |
| `AsyncStream` subscriber must be cancelled | Document lifecycle; app owns task cancellation on deinit |
| Identity key as raw `Data` vs `Curve25519.KeyAgreement.PrivateKey` | Use `Data` to match `unwrapIdentityPrivateKey` output; auth converts at boundary |
| Actor protocol ergonomics (`any VaultSession`) | Use `any VaultSession` at injection sites; tests use concrete actor or test double actor |

## Migration Plan

1. Add `Packages/VaultSession` package with tests (this change)
2. Link products in Xcode project (no runtime behavior change until auth exists)
3. Future auth change: unlock → `establish(VaultSessionKeys)`; lock → `clear()`
4. Future app: observe `changes` for root navigation

No data migration — purely new in-memory module.

## Open Questions

None — decisions from exploration are captured above.
