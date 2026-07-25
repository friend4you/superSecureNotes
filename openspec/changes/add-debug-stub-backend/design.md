## Context

`AppDependencies` always constructs `NetworkAuthRepository` and `NetworkVaultRepository` against `https://api.example.com/v1`. Auth and vault view models (`DefaultLoginViewModel`, `DefaultRegisterViewModel`) already orchestrate the full pipeline: remote auth → vault header read/write → `SecureCryptoVaultAuthenticator` unlock → `VaultSession.establish`. `RootView` observes `vaultSession.changes` and calls `SessionRootNavigation.apply` to switch between `AuthRoute.login` and `NotesRoute.list`.

Test targets already contain `MockAuthRepository`, `MockVaultRepository`, and `URLProtocolStub`, but none are wired into the runnable app. `PreviewSupport` in `AuthFlowUI` uses fake crypto and a non-emitting vault session, so previews cannot exercise the full navigation loop.

## Goals / Non-Goals

**Goals:**

- DEBUG-only stub backend activated by launch argument `-UseStubBackend`
- `InMemoryAuthRepository` implementing `AuthRepository` — any email/password succeeds
- `FileVaultRepository` implementing `VaultRepository` — persists header `Data` to app sandbox file
- Real `SecureCryptoVaultAuthenticator` and `VaultSession` in stub mode
- Full manual flow: register → notes, logout → login → notes, kill app → login → notes
- DEBUG-only logout button on `NoteListView` via `DefaultNoteListViewModel`
- `NotesFlowDependencies` extended with `authRepository` and `vaultSession` (same pattern as `AuthFlowDependencies`)
- Strict TDD for all new behavior

**Non-Goals:**

- Stub mode in Release builds
- Network-layer stubs (`URLProtocol`, local HTTP server)
- Production logout UX (settings screen, confirmation dialog)
- Keychain or persistent auth token storage in stub mode
- Notes data loading or encryption

## Decisions

### 1. Launch argument gate: `-UseStubBackend`

```swift
#if DEBUG
enum StubBackendConfiguration {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UseStubBackend")
    }
}
#endif
```

`AppDependencies` checks this flag and selects repository implementations.

**Rationale:** Explicit opt-in avoids accidental stub use during backend integration testing. Launch arguments are standard for Xcode scheme configuration and require no UI toggle.

**Alternatives considered:**
- Always stub in DEBUG — rejected; need to test real network wiring before backend is ready
- UserDefaults toggle — rejected; less discoverable, persists across launches unintentionally

### 2. Stub repositories live in the app target

```
superSecureNotes/
├── Stub/
│   ├── InMemoryAuthRepository.swift
│   └── FileVaultRepository.swift
└── AppDependencies.swift
```

**Rationale:** Stubs are DEBUG-only app composition concerns, not reusable library code. Keeps protocol packages (`AuthRepositoryProtocol`, `VaultRepositoryProtocol`) free of debug implementations.

**Alternatives considered:**
- Shared `DebugSupport` package — rejected; YAGNI for two small types
- Reuse test mocks from `AuthFlowMocks.swift` — rejected; test targets are not linked to app; mocks lack file persistence

### 3. File persistence for vault header

`FileVaultRepository` stores opaque header bytes at:

```
Application Support/stub-vault/vault-header.bin
```

- `writeHeader(_:)` — create directory if needed, atomically write file
- `readHeader()` — read file; throw `VaultRepositoryError.headerNotFound` if missing
- `fetchPublicKey(userID:)` — return 32 zero bytes (unused in current auth flow)

**Rationale:** Enables kill-app → relaunch → login testing with real crypto. Application Support is the standard sandbox location for app-private data.

**Alternatives considered:**
- UserDefaults — rejected; binary header data is awkward and size-limited
- In-memory only — rejected per user requirement

### 4. InMemoryAuthRepository behavior

- `register` / `login` — succeed with any non-empty credentials; store `AuthSession` and `User` in actor state
- `logout` — clear session and user (no network call)
- `refreshSession` — return current session or throw `notAuthenticated`
- `currentSession` / `currentUser` — reflect in-memory state

**Rationale:** Minimal stub focused on flow testing. Validation of empty credentials remains in view models.

### 5. NotesFlow logout architecture

Mirror `AuthFlowDependencies` pattern:

```
NotesDependencyProviding
  └── makeNoteListViewModel() -> DefaultNoteListViewModel

DefaultNoteListViewModel
  └── logout() async
        → authRepository.logout()
        → vaultSession.clear()
        → (RootView reacts via vaultSession.changes)
```

`NoteListView` shows a DEBUG-only toolbar logout button that calls `viewModel.logout()`.

**Rationale:** Consistent with existing module dependency pattern. View model is testable without SwiftUI. `vaultSession.clear()` triggers existing root navigation — no manual `navigator.setRoot` needed.

### 6. NotesFlow package dependencies

Add to `NotesFlow` target:

- `AuthRepositoryProtocol` (from `AuthFlow` package path)
- `VaultSessionProtocol` (from `VaultSession` package path)

**Rationale:** Logout needs auth and session contracts only — no network or crypto imports.

### 7. Xcode scheme configuration

Add `-UseStubBackend` to the Debug scheme's Run → Arguments → Arguments Passed On Launch.

Document in a code comment on `StubBackendConfiguration` and in tasks.

## Risks / Trade-offs

- **[Stub data persists across debug sessions]** → Acceptable for dev; document file location; optional future task to add "reset stub data" debug action
- **[Stub auth accepts any password on login]** → Acceptable; real crypto still validates password against persisted header
- **[FileVaultRepository not thread-safe across processes]** → Single app instance only; actor isolation sufficient
- **[DEBUG logout button not in Release]** → Intentional; production logout is a future change

## Migration Plan

1. Implement stub repositories and tests
2. Wire `AppDependencies` with launch-argument gate
3. Extend `NotesFlow` with view model and logout
4. Add Xcode scheme launch argument
5. Manual verification: register → notes → logout → login → kill app → login

No rollback needed — Release builds exclude all stub code via `#if DEBUG`.

## Open Questions

None — all decisions confirmed with user.
