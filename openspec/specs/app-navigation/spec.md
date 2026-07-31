# App Navigation

## Purpose

Defines how the app composes auth, notes, and lock/logout flows — including `NotesIndexStore` lifecycle wiring at the composition root.

## Requirements

### Requirement: Notes index store opened after vault unlock

After successful vault unlock, auth view models (`DefaultUnlockViewModel`, `DefaultLoginViewModel`, `DefaultRegisterViewModel`) SHALL call `notesIndexStore.open(passphrase:)` with a UDK-derived passphrase from `deriveNotesDatabaseKey` before navigating to the notes flow. `open` SHALL be called after `vaultSession.establish(_:)` succeeds and before any notes screen is shown.

#### Scenario: Unlock opens notes index store

- **WHEN** unlock with password succeeds
- **THEN** `notesIndexStore.open(passphrase:)` is called after `vaultSession.establish` and before navigation to notes

#### Scenario: Login opens notes index store

- **WHEN** login succeeds and vault session is established
- **THEN** `notesIndexStore.open(passphrase:)` is called before navigation to notes

#### Scenario: Register opens notes index store

- **WHEN** registration succeeds and vault session is established
- **THEN** `notesIndexStore.open(passphrase:)` is called before navigation to notes

#### Scenario: Failed unlock does not open index store

- **WHEN** unlock fails before `vaultSession.establish`
- **THEN** `notesIndexStore.open` is not called

### Requirement: Auth layer receives NotesIndexStore

`AppComposition` SHALL construct a shared `NotesIndexStore` instance and pass it to auth view models (`DefaultUnlockViewModel`, `DefaultLoginViewModel`, `DefaultRegisterViewModel`) and lock/logout coordinators. `NotesFlow` dependencies SHALL receive `noteRepository` only — not `NotesIndexStore`.

#### Scenario: Unlock view model has notes index store

- **WHEN** `AppComposition` constructs the unlock view model
- **THEN** it receives the shared `NotesIndexStore` instance

#### Scenario: Notes flow dependencies do not receive notes index store

- **WHEN** `NotesFlowDependencies` is constructed
- **THEN** it receives `noteRepository` but does not receive `NotesIndexStore`

### Requirement: LockCoordinator closes notes index store

`LockCoordinator.lock()` SHALL call `notesIndexStore.close()` before `vaultSession.clear()`.

#### Scenario: Lock coordinator closes index store

- **WHEN** `LockCoordinator.lock()` is invoked
- **THEN** `notesIndexStore.close()` is called before `vaultSession.clear()`

### Requirement: LogoutReset closes notes index store

`LogoutReset.perform` SHALL accept `notesIndexStore` and call `close()` before `vaultSession.clear()`.

#### Scenario: Logout reset closes index store

- **WHEN** `LogoutReset.perform` is called
- **THEN** `notesIndexStore.close()` is called before `vaultSession.clear()`
