## MODIFIED Requirements

### Requirement: Empty-local vault pull on first login

After successful authentication on the login screen (`hasLocalSetup == false`), when the local vault header file is missing, the app SHALL download the vault header from `GET /v1/vault/header`, unlock the vault with the user's password, open the notes index, then download owned notes from `GET /v1/notes` and each note blob from `GET /v1/notes/{noteId}`, storing them locally with `syncState: .synced` and the server etag when available. When a local vault header file already exists, the app SHALL NOT perform a full remote catalog pull during login.

#### Scenario: New device login pulls vault and notes

- **WHEN** login succeeds and the local vault header file is not found
- **THEN** the vault header and all owned remote notes are stored locally as synced before the user reaches the notes list

#### Scenario: Existing local vault skips full pull

- **WHEN** login succeeds and a local vault header file already exists
- **THEN** the app does not replace local notes with a full remote catalog pull

#### Scenario: Remote vault missing on new device

- **WHEN** login succeeds, the local vault header file is missing, and `GET /v1/vault/header` returns not found
- **THEN** the login flow fails with a vault-not-found style error (user must register/create vault)

### Requirement: Register pushes vault header

After register creates and writes the vault header locally, the app SHALL upload the header via `PUT /v1/vault/header` as `application/octet-stream` and **await** success before completing register. Register SHALL fail if the upload does not succeed.

#### Scenario: Register uploads vault header before success

- **WHEN** register writes the local vault header
- **THEN** the app awaits `PUT /v1/vault/header` and only completes register on success

#### Scenario: Register fails when vault upload fails

- **WHEN** `PUT /v1/vault/header` fails after local vault creation
- **THEN** register fails, device setup is not marked complete, and the app attempts auth session cleanup

## REMOVED Requirements

### Requirement: Register pushes vault header (fire-and-forget variant)

**Reason:** Replaced by blocking upload that must succeed before register completes.

**Migration:** Use await upload in `DefaultRegisterViewModel`; remove reliance on `scheduleVaultHeaderUpload` for the register success path.

#### Scenario: Register uploads vault header asynchronously

- **WHEN** register successfully writes the local vault header
- **THEN** ~~a network vault header upload is started without blocking completion of the local register success path~~ (removed)
