## ADDED Requirements

### Requirement: Local-first sync orchestrator

The app SHALL provide a sync orchestrator that uses local vault and note repositories as the source of truth and network vault/note clients for transport. ViewModels SHALL continue to perform CRUD only against the local `NoteRepository`. The orchestrator SHALL push pending local changes asynchronously without blocking the calling UI flow.

#### Scenario: Create does not wait for network

- **WHEN** a note is saved locally with `syncState: .pendingSync`
- **THEN** the save completes successfully even if the network push has not finished

#### Scenario: Orchestrator uses local repository for reads after sync

- **WHEN** a remote note has been pulled into local storage
- **THEN** subsequent `listNotes` / `readNote` go to the local repository only

### Requirement: Empty-local vault pull on first login

After successful authentication, when the local vault header is missing, the sync orchestrator SHALL download the vault header from `GET /vault/header`, and after vault unlock and notes index open, SHALL download owned notes from `GET /notes` and each note blob from `GET /notes/{noteId}`, storing them locally with `syncState: .synced` and the server etag when available. When a local vault header already exists, the orchestrator SHALL NOT perform a full catalog pull.

#### Scenario: New device login pulls vault and notes

- **WHEN** login succeeds and local vault header is not found
- **THEN** the vault header and all owned remote notes are stored locally as synced

#### Scenario: Existing local vault skips full pull

- **WHEN** login or unlock succeeds and a local vault header already exists
- **THEN** the orchestrator does not replace local notes with a full remote catalog pull

#### Scenario: Remote vault missing on new device

- **WHEN** login succeeds, local vault is missing, and `GET /vault/header` returns not found
- **THEN** the login/unlock flow fails with a vault-not-found style error (user must register/create vault)

### Requirement: Register pushes vault header

After register creates and writes the vault header locally, the sync orchestrator SHALL fire-and-forget upload the header via `PUT /vault/header` as `application/octet-stream`.

#### Scenario: Register uploads vault header asynchronously

- **WHEN** register successfully writes the local vault header
- **THEN** a network vault header upload is started without blocking completion of the local register success path

### Requirement: Push pending note uploads

The sync orchestrator SHALL upload locally stored notes with `syncState: .pendingSync` via `PUT /notes/{noteId}` using wire-format `.note` bytes. On success (`200` with etag metadata), it SHALL persist the etag and set `syncState` to `synced`.

#### Scenario: Pending note becomes synced after successful PUT

- **WHEN** flush runs for a note in `pendingSync` and the server returns success with an etag
- **THEN** the local note etag is stored and `syncState` is `synced`

### Requirement: Last-write-wins on conflict

When a note push receives HTTP `409`, the orchestrator SHALL fetch the remote note, compare `updatedAt` values, and keep the newer side: if local is newer, retry upload; if remote is newer, overwrite local storage with the remote blob and mark `synced`.

#### Scenario: Local newer wins after 409

- **WHEN** push returns 409 and local `updatedAt` is greater than remote `updatedAt`
- **THEN** the orchestrator retries uploading the local note

#### Scenario: Remote newer wins after 409

- **WHEN** push returns 409 and remote `updatedAt` is greater than local `updatedAt`
- **THEN** local storage is replaced with the remote note and `syncState` is `synced`

### Requirement: Enqueued remote delete

When the user deletes a note, the app SHALL remove the note from local listing immediately and enqueue a remote `DELETE /notes/{noteId}`. The orchestrator SHALL perform the remote delete during flush; failures SHALL leave the delete pending for retry without bringing the note back into the visible list.

#### Scenario: Delete removes note from list before remote ack

- **WHEN** the user confirms delete
- **THEN** the note no longer appears in `listNotes` even if the remote DELETE has not completed

#### Scenario: Failed remote delete retries later

- **WHEN** remote DELETE fails during flush
- **THEN** a subsequent flush retries the delete without restoring the note to the UI list

### Requirement: Flush retry triggers

The sync orchestrator SHALL flush pending uploads and deletes when: (1) unlock completes while online, (2) the notes list refresh/pull-to-refresh runs, and (3) network reachability transitions to online.

#### Scenario: Unlock online flushes pending work

- **WHEN** unlock succeeds and the device is online
- **THEN** pending note uploads and deletes are flushed

#### Scenario: Pull-to-refresh flushes pending work

- **WHEN** the note list refresh runs
- **THEN** pending note uploads and deletes are flushed in addition to reloading local list data

### Requirement: Localhost API composition without stub backend

`AppDependencies` SHALL set the API base URL to `http://localhost:8000/v1` and SHALL construct `NetworkAuthRepository` for auth in all builds. The app SHALL NOT provide `-UseStubBackend`, `InMemoryAuthRepository`, or stub-backend configuration gating.

#### Scenario: Auth uses network repository against localhost

- **WHEN** `AppDependencies` is initialized
- **THEN** `authRepository` is a `NetworkAuthRepository` configured with base URL `http://localhost:8000/v1`

#### Scenario: Stub backend flag is removed

- **WHEN** the DEBUG app launch arguments are inspected for stub backend support
- **THEN** `-UseStubBackend` is not a supported composition switch
