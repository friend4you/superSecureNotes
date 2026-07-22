## Context

`AuthFlow` already ships `AuthRepositoryProtocol` and `AuthRepository` for server account auth. `VaultRepository` handles vault header sync and public-key lookup. `SecureCrypto` provides `createVault`, `unlockVault`, and `unwrapIdentityPrivateKey`. `VaultSession` holds unlocked keys in memory. `NotesFlow` provides a placeholder note list but no auth gating.

The `add-auth-flow-repository` design deferred SwiftUI screens to a follow-up change. This change adds the UI and orchestration layer inside the same `AuthFlow` umbrella package, following the project's protocol/implementation split and strict TDD policy.

## Goals / Non-Goals

**Goals:**

- Add `AuthFlowProtocol` and `AuthFlowUI` library products to `Packages/AuthFlow/`
- Public `LoginView` and `RegisterView` with localized strings via `Localizable.xcstrings`
- `@Observable` default ViewModels with testable protocols in `AuthFlowProtocol`
- Register flow: account register → create vault → upload header → establish `VaultSession`
- Login flow: account login → fetch header → unlock vault → establish `VaultSession`
- `VaultAuthenticator` protocol in `AuthFlowProtocol`; default implementation in `AuthFlowUI` using `SecureCrypto`
- `AuthRepository` adapter conforming to `AccessTokenProviding` for `VaultRepository`
- App composition root presents `LoginView` when unauthenticated
- Strict TDD on ViewModels (red → green → refactor)

**Non-Goals:**

- Recovery-key / mnemonic recovery screen (mnemonic returned internally but not displayed in v1)
- Forgot password, email verification, password reset
- Biometrics, OAuth, social login
- Keychain or persistent token storage
- Auto-refresh of JWT tokens
- Full app router with authenticated/unauthenticated state machine beyond showing `LoginView` at root
- Snapshot tests for SwiftUI layout in v1

## Decisions

### 1. Extend `AuthFlow` package (not a new package)

```
Packages/AuthFlow/
├── Sources/
│   ├── AuthRepositoryProtocol/     ← existing
│   ├── AuthRepository/             ← existing
│   ├── AuthFlowProtocol/           ← NEW
│   └── AuthFlowUI/                 ← NEW
│       └── Resources/
│           └── Localizable.xcstrings
└── Tests/
    ├── AuthFlowProtocolTests/      ← NEW
    └── AuthFlowUITests/            ← NEW (minimal)
```

**Rationale:** Prior design chose `AuthFlow` as the umbrella for all auth-domain code. UI is the next slice.

**Alternatives considered:**
- Separate `AuthFlowUI` package — rejected; fragments the auth domain
- Single UI target without protocol split — rejected; ViewModels have real behavior requiring test seams

### 2. Protocol module depends on contract packages only

`AuthFlowProtocol` imports:
- `AuthRepositoryProtocol`
- `VaultRepositoryProtocol`
- `VaultSessionProtocol`
- `Foundation` (no SwiftUI)

`AuthFlowUI` imports:
- `AuthFlowProtocol`
- `SecureCrypto` (for `VaultAuthenticator` default impl)
- `SwiftUI`

**Rationale:** ViewModel tests mock protocols without SwiftUI or concrete crypto. Matches `AuthRepositoryProtocol` / `VaultRepositoryProtocol` zero-networking rule.

### 3. `VaultAuthenticator` protocol wraps crypto operations

```swift
public protocol VaultAuthenticator: Sendable {
    func createVault(password: String) throws -> VaultCreationOutcome
    func unlockVault(headerData: Data, password: String) throws -> VaultUnlockOutcome
}

public struct VaultCreationOutcome: Sendable, Equatable {
    public let headerData: Data
    public let mnemonic: [String]   // stored but not shown in v1 UI
}

public struct VaultUnlockOutcome: Sendable {
    public let sessionKeys: VaultSessionKeys
}
```

Default `SecureCryptoVaultAuthenticator` in `AuthFlowUI` calls `createVault`, `unlockVault`, `unwrapIdentityPrivateKey`, and builds `VaultSessionKeys`.

**Rationale:** Keeps `AuthFlowProtocol` free of `SecureCrypto` import while allowing TDD with a mock authenticator.

**Alternatives considered:**
- Import `SecureCrypto` directly in ViewModels — couples protocol target to crypto impl; rejected

### 4. Single password field per screen

Both login and register use one password field that serves account auth and vault create/unlock.

**Rationale:** Minimizes v1 UI complexity. User enters credentials once; ViewModel passes the same password to `AuthRepository` and vault operations.

**Alternatives considered:**
- Separate account password and vault password fields — more flexible but heavier UX; deferred

### 5. ViewModel protocols and state enums

```swift
public enum AuthFormState: Equatable, Sendable {
    case idle
    case loading
    case failure(AuthFlowError)
}

public enum AuthFlowError: Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case validationError
    case vaultNotFound
    case vaultUnlockFailed
    case networkError
    case unknown
}

@MainActor
public protocol LoginViewModel: Observable {
    var email: String { get set }
    var password: String { get set }
    var state: AuthFormState { get }
    func login() async
}

@MainActor
public protocol RegisterViewModel: Observable {
    var email: String { get set }
    var password: String { get set }
    var state: AuthFormState { get }
    func register() async
}
```

ViewModels map `AuthRepositoryError` and `VaultRepositoryError` to `AuthFlowError`. Views localize `AuthFlowError` cases — ViewModels never return display strings.

**Rationale:** TDD at ViewModel seam per `development-practices`. Locale-independent tests.

### 6. Register orchestration sequence

```
register(credentials)
  → AuthRepository.register
  → VaultAuthenticator.createVault(password)
  → VaultRepository.writeHeader(headerData)
  → VaultSession.establish(sessionKeys from unlock after create)
  → state = idle (success; app observes VaultSession)
```

After `createVault`, the authenticator unlocks with the same password to produce `VaultSessionKeys` (create does not return UDK directly).

### 7. Login orchestration sequence

```
login(credentials)
  → AuthRepository.login
  → VaultRepository.readHeader()
  → VaultAuthenticator.unlockVault(headerData, password)
  → VaultSession.establish(sessionKeys)
  → state = idle (success)
```

On `VaultRepositoryError.headerNotFound`, map to `AuthFlowError.vaultNotFound`.

On crypto unlock failure, map to `AuthFlowError.vaultUnlockFailed`.

### 8. Localization via `Localizable.xcstrings`

All user-visible strings in `AuthFlowUI/Resources/Localizable.xcstrings`. Views use:

```swift
Text("login.title", bundle: .module)
```

Key namespaces: `login.*`, `register.*`, `error.*`, `common.*`.

English only in v1. Catalog structure supports future locales.

**Rationale:** First localization in the project; establishes SPM resource pattern.

### 9. Navigation between login and register

`LoginView` includes a `NavigationLink` to `RegisterView` and vice versa. Views accept optional `onAuthenticated: () -> Void` callback for app-level routing after success.

**Rationale:** Package owns auth screen navigation; app owns post-auth destination.

**Alternatives considered:**
- App-owned `NavigationStack` with route enum — more flexible but more app wiring; deferred

### 10. `AccessTokenProviding` adapter

Add `AuthRepositoryAccessTokenProvider` in `AuthRepository` target:

```swift
public struct AuthRepositoryAccessTokenProvider: AccessTokenProviding {
    private let repository: any AuthRepository
    public func accessToken() async throws -> String {
        guard let session = await repository.currentSession else {
            throw VaultRepositoryError.notAuthenticated
        }
        return session.accessToken
    }
}
```

App passes this to `NetworkVaultRepository` init.

**Rationale:** Keeps token bridging at composition root boundary; `VaultRepository` already defines `AccessTokenProviding`.

### 11. App composition root

```swift
// superSecureNotesApp or dedicated AppDependencies
let authRepository = NetworkAuthRepository(baseURL: ...)
let tokenProvider = AuthRepositoryAccessTokenProvider(repository: authRepository)
let vaultRepository = NetworkVaultRepository(baseURL: ..., tokenProvider: tokenProvider)
let vaultSession = VaultSession()
let authenticator = SecureCryptoVaultAuthenticator()

// Root view
if await vaultSession.isActive {
    NoteListView()
} else {
    LoginView(viewModel: DefaultLoginViewModel(...))
}
```

**Rationale:** Minimal gating — show notes only when vault session is active.

### 12. Products and import guidance

| Consumer | Import |
|----------|--------|
| App composition root | `AuthFlowUI`, `AuthRepository`, `VaultRepository`, `VaultSession`, `SecureCrypto` |
| Tests / previews | `AuthFlowProtocol` (mocks) |
| Other feature packages | `AuthFlowProtocol` only (no SwiftUI) |

`AuthFlowUI` `@_exported import AuthFlowProtocol` at module entry.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Register + vault create is multi-step; partial failure leaves inconsistent state | Document: server account exists but vault upload failed → show `networkError`; user may need support/retry in future |
| Single password for account and vault | Document v1 UX choice; separate fields can be added later without protocol changes |
| No mnemonic display on register | User cannot recover without future recovery screen; documented non-goal |
| `VaultSession` observation in app root is simplistic | Sufficient for v1 gating; full router deferred |
| `SecureCrypto` dependency only in `AuthFlowUI` | `VaultAuthenticator` protocol keeps protocol target testable |
| Login when vault header missing | Map to `vaultNotFound` error with localized message |

## Migration Plan

Greenfield UI addition on existing packages.

1. Extend `AuthFlow/Package.swift` with new targets and path dependencies to sibling packages
2. Implement `AuthFlowProtocol` + tests (TDD)
3. Implement `AuthFlowUI` + localization + tests (TDD)
4. Add `AuthRepositoryAccessTokenProvider`
5. Wire app composition root

Rollback: remove app wiring and new targets; existing repository targets unaffected.

## Open Questions

- None for v1 — scope and orchestration decisions captured above.
