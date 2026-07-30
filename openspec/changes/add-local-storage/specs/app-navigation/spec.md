## ADDED Requirements

### Requirement: AppDependencies uses local repositories

`AppDependencies` SHALL construct `LocalNoteRepository` as `noteRepository` and `LocalVaultRepository` as `vaultRepository` in all builds (DEBUG and Release).

#### Scenario: Note repository is local in all builds

- **WHEN** `AppDependencies` is initialized in DEBUG or Release
- **THEN** `noteRepository` is a `LocalNoteRepository` instance

#### Scenario: Vault repository is local in all builds

- **WHEN** `AppDependencies` is initialized in DEBUG or Release
- **THEN** `vaultRepository` is a `LocalVaultRepository` instance

### Requirement: Stub backend controls auth only

When `StubBackendConfiguration.isEnabled` is true in DEBUG, `AppDependencies` SHALL construct `InMemoryAuthRepository` as `authRepository`. When stub mode is disabled, `AppDependencies` SHALL construct `NetworkAuthRepository`. Stub configuration SHALL NOT affect `noteRepository` or `vaultRepository` selection.

#### Scenario: Stub mode uses in-memory auth with local storage

- **WHEN** the app launches in DEBUG with `-UseStubBackend`
- **THEN** `authRepository` is an `InMemoryAuthRepository` instance and `noteRepository` is still `LocalNoteRepository`

#### Scenario: Non-stub DEBUG uses network auth with local storage

- **WHEN** the app launches in DEBUG without `-UseStubBackend`
- **THEN** `authRepository` is a `NetworkAuthRepository` instance and `noteRepository` is `LocalNoteRepository`

## REMOVED Requirements

### Requirement: Stub backend selects FileNoteRepository

**Reason**: Replaced by `LocalNoteRepository` in all builds; stub mode no longer selects note repository implementation.

**Migration**: Use `LocalNoteRepository` via `AppDependencies`; delete old `stub-notes/` data manually if present.

### Requirement: FileNoteRepository stub

**Reason**: Replaced by `LocalNoteRepository` in the `NoteRepository` package with split FEK storage.

**Migration**: No automatic migration; wipe app data and reinstall. New layout: `Application Support/superSecureNotes/notes/{uuid}/note` and `fek`.
