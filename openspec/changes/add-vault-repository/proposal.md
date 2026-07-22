## Why

superSecureNotes needs server-backed vault header storage and a public-key directory before multi-device vault sync and note sharing can work. `SecureCrypto` and `VaultSession` handle local crypto and in-memory keys, but nothing persists or fetches `vault.meta` from a backend, and nothing looks up another user's identity public key for FEK encryption. A dedicated repository with a protocol/implementation split — mirroring `AuthRepository` — gives future vault auth and sharing modules a stable contract while the backend is still being built.

## What Changes

- Add a new Swift Package `VaultRepository` with two library products: `VaultRepositoryProtocol` (contracts and shared types) and `VaultRepository` (network implementation)
- Define `VaultRepository` protocol with `readHeader()`, `writeHeader(_:)`, and `fetchPublicKey(userID:)`
- Define `AccessTokenProviding` protocol for injected bearer-token auth (no dependency on `AuthRepository`)
- Define `VaultRepositoryError` with typed error cases including `headerNotFound` and `publicKeyNotFound`
- Implement `NetworkVaultRepository` actor using internal `URLSession` HTTP client (not exposed as a public protocol)
- Define a v1 REST API contract for vault header upload/download and public-key lookup — shared contract for Swift client and future backend
- Repository deals in raw `Data` for headers; `VaultHeader` parse/serialize stays in `SecureCrypto` callers
- One vault per authenticated account; server indexes `identity_public_key` from uploaded v2 headers for directory lookups
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `vault-repository`: Server-backed vault header persistence and user public-key lookup — package boundary, protocol models, token provider injection, network implementation, proposed REST API contract

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/VaultRepository/` — new package (`VaultRepositoryProtocol` + `VaultRepository` targets)
- `superSecureNotes.xcodeproj` — link products (no app wiring until vault auth / sharing modules exist)
- Future backend — implement endpoints defined in `design.md` REST contract
- Out of scope: local file storage, note file sync, vault unlock orchestration, `SecureCrypto` / `VaultSession` integration, sharing UX, separate `publishPublicKey` endpoint, SwiftUI screens
