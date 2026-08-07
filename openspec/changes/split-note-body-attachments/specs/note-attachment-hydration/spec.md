## ADDED Requirements

### Requirement: Attachment hydration orchestration

`LocalFirstNoteSyncService` SHALL download missing attachment files for a note when local ciphertext is absent and remote manifest entries exist. Downloads SHALL continue after the user leaves the detail screen. Failed downloads SHALL be retried per attachment id without restarting completed siblings.

#### Scenario: Hydration continues after leaving detail

- **WHEN** the user pops the detail screen while attachments are downloading
- **THEN** in-flight downloads continue and complete to local attachment files

#### Scenario: Retry single failed attachment

- **WHEN** one attachment download fails and others succeed
- **THEN** retry targets only the failed attachment id

### Requirement: Parallel attachment download cap

Attachment hydration SHALL run up to 3 concurrent downloads per note.

#### Scenario: Fourth attachment waits for slot

- **WHEN** a note has four missing attachments and three downloads are in progress
- **THEN** the fourth download starts only after one of the three completes

### Requirement: Per-attachment download progress

The sync layer SHALL expose per-attachment download progress as bytes received over total size for subscribers (detail and shared detail view models).

#### Scenario: Progress updates during download

- **WHEN** an attachment download receives additional bytes
- **THEN** subscribers receive an updated fraction for that attachment id

### Requirement: Remote-only hydration trigger

Attachment hydration and download progress UI SHALL run only when local attachment files are missing (remote/cold path). When all attachment files exist locally, detail SHALL load attachments from disk without network download or progress UI.

#### Scenario: Warm local open skips hydration

- **WHEN** detail opens and all attachment files exist under `attachments/`
- **THEN** no attachment download is started and no per-row progress is shown

#### Scenario: Cold open starts hydration

- **WHEN** detail opens with decrypted body/index but missing attachment files
- **THEN** hydration downloads begin and progress is published per attachment

### Requirement: Shared note attachment hydration

Shared note detail SHALL use shared attachment endpoints (`/v1/notes/shared/{noteId}/attachments/...`) with the same hydration, progress, parallelism, and retry behavior as owned notes.

#### Scenario: Shared detail shows per-attachment progress

- **WHEN** a shared note is opened without local attachment files
- **THEN** per-attachment download progress is shown using shared endpoints
