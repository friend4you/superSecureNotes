# VaultSession

Swift package providing in-memory vault key session storage for superSecureNotes.

## Module layout

```
superSecureNotes (app)
    ├── VaultSessionProtocol   ← feature modules should depend on this
    └── VaultSession           ← composition root / default actor implementation

VaultSession
    └── VaultSessionProtocol

VaultSessionProtocol
    └── CryptoKit (SymmetricKey only)
```

### Source folders

```
Sources/VaultSessionProtocol/
├── VaultSession.swift          VaultSession protocol
└── Shared/                     VaultSessionKeys, VaultSessionError

Sources/VaultSession/
├── VaultSession.swift          re-export entry point
└── VaultSessionActor.swift     actor VaultSession implementation

Tests/ mirror the same folders per target.
```

## Import guidance

| Consumer | Import | Why |
|----------|--------|-----|
| Feature modules (notes, sharing) | `VaultSessionProtocol` | Protocol, shared types — no concrete actor |
| Auth module (future) | `VaultSessionProtocol` + `VaultSession` | Establish/clear session after unlock |
| App composition root | `VaultSession` | Wire `actor VaultSession` and inject as `any VaultSessionProtocol.VaultSession` |

`VaultSession` re-exports `VaultSessionProtocol` via `@_exported import`, so `import VaultSession` exposes both the actor and the protocol module types.

## Responsibilities

**VaultSession owns:**

- In-memory UDK and identity private key while session is active
- `establish` / `clear` lifecycle (called by auth module only, by convention)
- `changes: AsyncStream<Bool>` for activity observation

**VaultSession does not:**

- Password unlock, mnemonic recovery, biometrics, or Keychain
- Navigation, lock timers, or `vault.meta` persistence

## Products

- **VaultSessionProtocol** — `VaultSession` protocol, `VaultSessionKeys`, `VaultSessionError`
- **VaultSession** — `actor VaultSession` default in-memory implementation

## Testing

```bash
cd Packages/VaultSession && swift test
```
