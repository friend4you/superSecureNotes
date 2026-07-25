## Why

The app wires `NetworkAuthRepository` and `NetworkVaultRepository` to `https://api.example.com/v1`, but no backend exists yet. Developers cannot manually exercise the full register → vault unlock → notes flow, or verify that real `SecureCrypto` integration works end-to-end. A DEBUG-only stub backend with file-persisted vault headers unblocks local flow testing without waiting for the API.

## What Changes

- Add DEBUG-only launch-argument gate (`-UseStubBackend`) in `AppDependencies` to swap network repositories for in-memory / file-backed stubs
- Add `InMemoryAuthRepository` — accepts any credentials, stores session in memory, supports logout
- Add `FileVaultRepository` — persists vault header bytes to the app sandbox so login works after app restart
- Keep `SecureCryptoVaultAuthenticator` and `VaultSession` as the real implementations (no fake crypto)
- Extend `NotesFlow` with dependency injection matching `AuthFlowDependencies` (`authRepository`, `vaultSession`)
- Add `DefaultNoteListViewModel` with `logout()` that clears auth session and vault session
- Add DEBUG-only logout button on `NoteListView`
- Document Xcode scheme launch argument for stub mode

## Capabilities

### New Capabilities

- `debug-stub-backend`: DEBUG-only stub auth and file-persisted vault repositories, launch-argument wiring in the app target

### Modified Capabilities

- `notes-flow`: Dependency injection for logout, `NoteListViewModel`, DEBUG-only logout UI

## Impact

- `superSecureNotes/` — stub repository types, `AppDependencies` conditional wiring, Xcode scheme launch argument
- `Packages/NotesFlow/` — new dependencies on `AuthRepositoryProtocol` and `VaultSessionProtocol`; `NotesDependencyProviding` factory method; view model and DEBUG logout button
- `superSecureNotes/AppComposition.swift` — pass `authRepository` and `vaultSession` into `NotesFlowDependencies`
- Release builds unaffected — all stub and logout UI code behind `#if DEBUG`
- Out of scope: mock server, URLProtocol interception, production logout UX, Keychain token persistence
