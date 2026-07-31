## ADDED Requirements

### Requirement: Note database opened after vault unlock

After successful vault unlock, auth view models (`DefaultUnlockViewModel`, `DefaultLoginViewModel`, `DefaultRegisterViewModel`) SHALL call `noteRepository.openDatabase(passphrase:)` with a UDK-derived passphrase before navigating to the notes flow. `openDatabase` SHALL be called after `vaultSession.establish(_:)` succeeds.

#### Scenario: Unlock opens note database

- **WHEN** unlock with password succeeds
- **THEN** `noteRepository.openDatabase(passphrase:)` is called before navigation to notes

#### Scenario: Login opens note database

- **WHEN** login succeeds and vault session is established
- **THEN** `noteRepository.openDatabase(passphrase:)` is called before navigation to notes

#### Scenario: Register opens note database

- **WHEN** registration succeeds and vault session is established
- **THEN** `noteRepository.openDatabase(passphrase:)` is called before navigation to notes

#### Scenario: Failed unlock does not open database

- **WHEN** unlock fails before `vaultSession.establish`
- **THEN** `noteRepository.openDatabase` is not called

### Requirement: Auth view models receive note repository

`AppComposition` SHALL pass `noteRepository` to `DefaultUnlockViewModel`, `DefaultLoginViewModel`, and `DefaultRegisterViewModel` factory methods for database lifecycle calls.

#### Scenario: Unlock view model has note repository

- **WHEN** `AppComposition` constructs the unlock view model
- **THEN** it receives the same `noteRepository` instance as `AppDependencies`

### Requirement: LockCoordinator closes note database

`LockCoordinator.lock()` SHALL call `noteRepository.closeDatabase()` before `vaultSession.clear()`.

#### Scenario: Lock coordinator closes database

- **WHEN** `LockCoordinator.lock()` is invoked
- **THEN** `noteRepository.closeDatabase()` is called before `vaultSession.clear()`

### Requirement: LogoutReset closes note database

`LogoutReset.perform` SHALL accept `noteRepository` and call `closeDatabase()` before `vaultSession.clear()`.

#### Scenario: Logout reset closes database

- **WHEN** `LogoutReset.perform` is called
- **THEN** `noteRepository.closeDatabase()` is called before `vaultSession.clear()`
