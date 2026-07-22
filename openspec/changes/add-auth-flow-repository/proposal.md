## Why

superSecureNotes needs server-backed account authentication (email/password login and registration) before note sync and multi-device features can be built. A dedicated repository layer with a protocol/implementation split gives the future `AuthFlow` UI a stable, testable contract while the backend is still being designed — the proposed REST API in this change becomes the contract both the Swift client and the future server implement against.

## What Changes

- Add a new Swift Package `AuthFlow` with two library products: `AuthRepositoryProtocol` (contracts and models) and `AuthRepository` (network implementation)
- Define `AuthRepository` protocol with `register`, `login`, `logout`, `refreshSession`, and session/user accessors
- Define shared models: `LoginCredentials`, `RegisterCredentials`, `User`, `AuthSession`, `AuthRepositoryError`
- Implement `NetworkAuthRepository` actor using internal `URLSession` HTTP client (not exposed as a public protocol)
- Define a v1 REST API contract (email/password, JWT access + refresh tokens) for backend development to follow
- Store session state in memory only (no Keychain persistence in v1)
- Strict TDD: failing tests before each implementation task

## Capabilities

### New Capabilities

- `auth-flow-repository`: Account auth repository — package boundary, protocol models, network implementation, in-memory session, proposed REST API contract

### Modified Capabilities

<!-- No existing main specs to modify -->

## Impact

- `Packages/AuthFlow/` — new package (`AuthRepositoryProtocol` + `AuthRepository` targets)
- `superSecureNotes.xcodeproj` — link products (no app wiring until AuthFlow UI exists)
- Future backend — implement endpoints defined in `design.md` REST contract
- Out of scope: SwiftUI login/register screens, Keychain token persistence, biometrics, `VaultSession` / `SecureCrypto` integration, OAuth/social login
