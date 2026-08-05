## ADDED Requirements

### Requirement: Split vault and note pull on sync orchestrator

The sync orchestrator SHALL expose separate operations for (1) downloading and persisting the vault header when the local vault file is missing, and (2) downloading owned notes into local storage after the notes index is open. Note catalog import SHALL NOT run before the notes index is open.

#### Scenario: Vault pull skips when local file exists

- **WHEN** `pullVaultHeaderIfLocalMissing()` is called and `LocalVaultRepository.readHeader()` succeeds
- **THEN** no network vault request is made and the method returns `nil`

#### Scenario: Vault pull fetches and writes header

- **WHEN** `pullVaultHeaderIfLocalMissing()` is called and the local vault file is missing
- **THEN** the orchestrator sends `GET /v1/vault/header`, writes the response to local vault storage, and returns the header bytes

#### Scenario: Note catalog pull imports synced notes

- **WHEN** `pullRemoteNotesCatalog()` is called and the notes index is open
- **THEN** the orchestrator lists remote notes, downloads each note blob, and stores them locally with `syncState: .synced` and server etag when available

#### Scenario: Note catalog pull requires open index

- **WHEN** `pullRemoteNotesCatalog()` is called before the notes index is open
- **THEN** the operation fails with a repository/index error (caller must open index after unlock first)

### Requirement: Register awaits vault header upload

After register creates the vault and writes the header locally, the app SHALL upload the header via `PUT /v1/vault/header` with `Content-Type: application/octet-stream` and **await** completion before establishing the vault session and saving device setup. Register SHALL NOT complete successfully if the upload fails.

#### Scenario: Register succeeds when vault upload succeeds

- **WHEN** register completes with HTTP `204` from `PUT /v1/vault/header`
- **THEN** `hasLocalSetup` becomes true, vault session is established, and the user proceeds to notes

#### Scenario: Register fails when vault upload fails

- **WHEN** local vault header was written but `PUT /v1/vault/header` fails with a network or server error
- **THEN** register completes with failure, `hasLocalSetup` remains false, and the app attempts to clear the auth session

#### Scenario: Register does not use fire-and-forget vault upload

- **WHEN** register completes successfully
- **THEN** the vault header already exists on the server before navigation away from the register flow (not merely scheduled for later upload)

### Requirement: Login pulls vault and notes when local vault is missing

When login succeeds on a device without a local vault header file, the app SHALL pull the vault header from the server, unlock the vault with the entered password, open the notes index, pull owned notes from the server, and persist setup credentials including the vault header.

#### Scenario: Fresh device login restores vault and notes

- **WHEN** login succeeds, the local vault file is missing, and the server has a vault header and notes
- **THEN** the vault header and all owned notes are stored locally as synced and the user reaches the notes list

#### Scenario: Login uses local vault when file exists

- **WHEN** login succeeds and a local vault header file already exists
- **THEN** the app reads the local vault header and does not replace local notes with a full remote catalog pull

#### Scenario: Login fails when remote vault missing

- **WHEN** login succeeds, the local vault file is missing, and `GET /v1/vault/header` returns not found
- **THEN** login fails with a vault-not-found style error

#### Scenario: Login injects sync orchestrator

- **WHEN** `AuthFlowDependencies.makeLoginViewModel()` is called in app composition
- **THEN** the login view model receives the same `LocalFirstNoteSyncService` instance used for register and unlock
